--- @module network
--- @file src/engine/backend/platform/windows/network.lua
--- @description Winsock backend: non-blocking TCP and UDP sockets. No protocol and no framing.

--- @section Imports

local _ffi = require("ffi")
local _bit = require("bit")
local _log = require("src.engine.core.log")

--- @section FFI

if _ffi.os ~= "Windows" then error("network backend: Windows only") end

_ffi.cdef[[
    typedef intptr_t socket_t;
    typedef struct { short sin_family; unsigned short sin_port; unsigned int sin_addr; char sin_zero[8]; } sockaddr_in_t;
    typedef struct { unsigned int fd_count; socket_t fd_array[64]; } fd_set_t;
    typedef struct { long tv_sec; long tv_usec; } timeval_t;

    int WSAStartup(unsigned short version, void *data);
    int WSACleanup(void);
    int WSAGetLastError(void);
    socket_t socket(int af, int type, int protocol);
    int closesocket(socket_t s);
    int shutdown(socket_t s, int how);
    int bind(socket_t s, const void *name, int namelen);
    int listen(socket_t s, int backlog);
    socket_t accept(socket_t s, void *addr, int *addrlen);
    int connect(socket_t s, const void *name, int namelen);
    int send(socket_t s, const char *buf, int len, int flags);
    int recv(socket_t s, char *buf, int len, int flags);
    int sendto(socket_t s, const char *buf, int len, int flags, const void *to, int tolen);
    int recvfrom(socket_t s, char *buf, int len, int flags, void *from, int *fromlen);
    int setsockopt(socket_t s, int level, int optname, const char *optval, int optlen);
    int getsockopt(socket_t s, int level, int optname, char *optval, int *optlen);
    int ioctlsocket(socket_t s, unsigned long cmd, unsigned long *argp);
    int getsockname(socket_t s, void *name, int *namelen);
    int select(int nfds, fd_set_t *readfds, fd_set_t *writefds, fd_set_t *exceptfds, const timeval_t *timeout);
    unsigned short htons(unsigned short value);
    unsigned short ntohs(unsigned short value);
    unsigned long inet_addr(const char *text);
]]

--- @section Constants & State

local _ws2 = _ffi.load("ws2_32")

local AF_INET, SOCK_STREAM, SOCK_DGRAM = 2, 1, 2
local IPPROTO_TCP, IPPROTO_UDP = 6, 17
local TCP_NODELAY = 1
local SOL_SOCKET, SO_ERROR, SO_TYPE = 0xFFFF, 0x1007, 0x1008
local FIONBIO = 0x8004667E
local SD_BOTH = 2
local SOCKADDR_SIZE = 16
local RECV_SIZE = 65536
local INVALID_SOCKET = _ffi.cast("socket_t", -1)
local WSAEWOULDBLOCK = 10035
local WSAECONNRESET = 10054

local MESSAGES = {
    [10038] = "not a socket",
    [10048] = "port already in use",
    [10049] = "invalid address",
    [10051] = "network unreachable",
    [10053] = "connection aborted",
    [10054] = "connection reset",
    [10060] = "connection timed out",
    [10061] = "connection refused",
    [10065] = "host unreachable",
}

local wsa_data = _ffi.new("char[512]")
if _ws2.WSAStartup(0x0202, wsa_data) ~= 0 then error("network backend: WSAStartup failed") end

local recv_buffer = _ffi.new("char[?]", RECV_SIZE)
local address = _ffi.new("sockaddr_in_t")
local int_value = _ffi.new("int[1]")
local nonblocking = _ffi.new("unsigned long[1]", 1)
local write_set, error_set = _ffi.new("fd_set_t"), _ffi.new("fd_set_t")
local no_wait = _ffi.new("timeval_t")

--- @section Initalisation

local m = {}

--- @section Functions

local function describe(code)
    return MESSAGES[code] or ("winsock error " .. code)
end

local function ip_string(packed)
    return ("%d.%d.%d.%d"):format(
        _bit.band(packed, 255),
        _bit.band(_bit.rshift(packed, 8), 255),
        _bit.band(_bit.rshift(packed, 16), 255),
        _bit.rshift(packed, 24)
    )
end

local function fill_address(ip, port)
    if type(ip) ~= "string" then return nil, "address must be a string" end
    if type(port) ~= "number" or port < 0 or port > 65535 or port % 1 ~= 0 then return nil, "invalid port" end

    local packed = _ws2.inet_addr(ip)
    if packed == 0xFFFFFFFF and ip ~= "255.255.255.255" then
        return nil, "invalid address '" .. ip .. "' (dotted IPv4 only)"
    end

    address.sin_family = AF_INET
    address.sin_port = _ws2.htons(port)
    address.sin_addr = packed
    for index = 0, 7 do address.sin_zero[index] = 0 end

    return address
end

local function make_socket(sock_type, protocol)
    local s = _ws2.socket(AF_INET, sock_type, protocol)
    if s == INVALID_SOCKET then return nil, describe(_ws2.WSAGetLastError()) end

    if _ws2.ioctlsocket(s, FIONBIO, nonblocking) ~= 0 then
        local code = _ws2.WSAGetLastError()
        _ws2.closesocket(s)
        return nil, describe(code)
    end

    if protocol == IPPROTO_TCP then
        int_value[0] = 1
        _ws2.setsockopt(s, IPPROTO_TCP, TCP_NODELAY, _ffi.cast("const char *", int_value), 4)
    end

    return s
end

local function handle(kind, s)
    return { kind = kind, s = s, closed = false }
end

local function socket_debug(s, label)
    local type_value = _ffi.new("int[1]")
    local type_len = _ffi.new("int[1]", 4)
    local addr = _ffi.new("sockaddr_in_t")
    local addr_len = _ffi.new("int[1]", SOCKADDR_SIZE)

    local type_result = _ws2.getsockopt(s, SOL_SOCKET, SO_TYPE, _ffi.cast("char *", type_value), type_len)
    local addr_result = _ws2.getsockname(s, addr, addr_len)

    local type_error = type_result ~= 0 and _ws2.WSAGetLastError() or 0
    local addr_error = addr_result ~= 0 and _ws2.WSAGetLastError() or 0

    _log.print("debug", ("%s socket=%s type_result=%d type=%d type_error=%d addr_result=%d addr_error=%d addr=%s:%d"):format(
        label,
        tostring(s),
        type_result,
        type_value[0],
        type_error,
        addr_result,
        addr_error,
        addr_result == 0 and ip_string(addr.sin_addr) or "?",
        addr_result == 0 and _ws2.ntohs(addr.sin_port) or 0
    ))
end

function m.tcp_listen(port, backlog)
    local addr, addr_err = fill_address("0.0.0.0", port)
    if not addr then return nil, addr_err end

    local s, err = make_socket(SOCK_STREAM, IPPROTO_TCP)
    if not s then return nil, err end

    socket_debug(s, "after socket")

    if _ws2.bind(s, addr, SOCKADDR_SIZE) ~= 0 then
        local code = _ws2.WSAGetLastError()
        _ws2.closesocket(s)
        return nil, describe(code)
    end

    socket_debug(s, "after bind")

    if _ws2.listen(s, backlog or 16) ~= 0 then
        local code = _ws2.WSAGetLastError()
        _ws2.closesocket(s)
        return nil, describe(code)
    end

    socket_debug(s, "after listen")

    return handle("listener", s)
end

function m.tcp_accept(listener)
    if not listener then return nil, "listener is nil" end
    if listener.closed then return nil, "listener is closed" end

    local client_address = _ffi.new("sockaddr_in_t")
    local client_address_length = _ffi.new("int[1]", SOCKADDR_SIZE)
    local s = _ws2.accept(listener.s, client_address, client_address_length)

    if s == INVALID_SOCKET then
        local code = _ws2.WSAGetLastError()
        if code == WSAEWOULDBLOCK then return nil end
        return nil, describe(code)
    end

    if _ws2.ioctlsocket(s, FIONBIO, nonblocking) ~= 0 then
        local code = _ws2.WSAGetLastError()
        _ws2.closesocket(s)
        return nil, describe(code)
    end

    int_value[0] = 1
    _ws2.setsockopt(s, IPPROTO_TCP, TCP_NODELAY, _ffi.cast("const char *", int_value), 4)

    local client = handle("tcp", s)
    client.connected = true

    return client, ip_string(client_address.sin_addr), _ws2.ntohs(client_address.sin_port)
end

function m.tcp_connect(ip, port)
    local addr, addr_err = fill_address(ip, port)
    if not addr then return nil, addr_err end

    local s, err = make_socket(SOCK_STREAM, IPPROTO_TCP)
    if not s then return nil, err end

    local socket = handle("tcp", s)

    if _ws2.connect(s, addr, SOCKADDR_SIZE) == 0 then
        socket.connected = true
        return socket
    end

    local code = _ws2.WSAGetLastError()
    if code ~= WSAEWOULDBLOCK then
        _ws2.closesocket(s)
        return nil, describe(code)
    end

    return socket
end

function m.tcp_status(socket)
    if socket.failed then return "failed", socket.reason end
    if socket.connected then return "connected" end

    write_set.fd_count, write_set.fd_array[0] = 1, socket.s
    error_set.fd_count, error_set.fd_array[0] = 1, socket.s

    local ready = _ws2.select(0, nil, write_set, error_set, no_wait)

    if ready < 0 then
        socket.failed, socket.reason = true, describe(_ws2.WSAGetLastError())
        return "failed", socket.reason
    end

    if error_set.fd_count > 0 then
        int_value[0] = 0
        local length = _ffi.new("int[1]", 4)
        _ws2.getsockopt(socket.s, SOL_SOCKET, SO_ERROR, _ffi.cast("char *", int_value), length)
        socket.failed, socket.reason = true, describe(int_value[0])
        return "failed", socket.reason
    end

    if write_set.fd_count > 0 then
        socket.connected = true
        return "connected"
    end

    return "connecting"
end

function m.tcp_send(socket, data)
    local length, total = #data, 0
    local pointer = _ffi.cast("const char *", data)

    while total < length do
        local sent = _ws2.send(socket.s, pointer + total, length - total, 0)

        if sent < 0 then
            local code = _ws2.WSAGetLastError()
            if code == WSAEWOULDBLOCK then break end
            return nil, describe(code)
        end

        total = total + sent
    end

    return total
end

function m.tcp_recv(socket)
    local count = _ws2.recv(socket.s, recv_buffer, RECV_SIZE, 0)

    if count > 0 then return _ffi.string(recv_buffer, count) end
    if count == 0 then return nil, "closed" end

    local code = _ws2.WSAGetLastError()
    if code == WSAEWOULDBLOCK then return "" end

    return nil, describe(code)
end

function m.udp_open(port)
    local addr, addr_err = fill_address("0.0.0.0", port or 0)
    if not addr then return nil, addr_err end

    local s, err = make_socket(SOCK_DGRAM, IPPROTO_UDP)
    if not s then return nil, err end

    if _ws2.bind(s, addr, SOCKADDR_SIZE) ~= 0 then
        local code = _ws2.WSAGetLastError()
        _ws2.closesocket(s)
        return nil, describe(code)
    end

    return handle("udp", s)
end

function m.udp_send(socket, data, ip, port)
    local addr, addr_err = fill_address(ip, port)
    if not addr then return nil, addr_err end

    local sent = _ws2.sendto(socket.s, data, #data, 0, addr, SOCKADDR_SIZE)
    if sent >= 0 then return sent end

    local code = _ws2.WSAGetLastError()
    if code == WSAEWOULDBLOCK then return 0 end

    return nil, describe(code)
end

function m.udp_recv(socket)
    int_value[0] = SOCKADDR_SIZE

    local count = _ws2.recvfrom(socket.s, recv_buffer, RECV_SIZE, 0, address, int_value)

    if count >= 0 then
        return _ffi.string(recv_buffer, count), ip_string(address.sin_addr), _ws2.ntohs(address.sin_port)
    end

    local code = _ws2.WSAGetLastError()
    if code == WSAEWOULDBLOCK or code == WSAECONNRESET then return nil end

    return nil, describe(code)
end

function m.local_port(socket)
    int_value[0] = SOCKADDR_SIZE
    if _ws2.getsockname(socket.s, address, int_value) ~= 0 then return nil end
    return _ws2.ntohs(address.sin_port)
end

function m.close(socket)
    if not socket or socket.closed then return end

    socket.closed = true

    if socket.kind == "tcp" then
        _ws2.shutdown(socket.s, SD_BOTH)
    end

    _ws2.closesocket(socket.s)
end

function m.cleanup()
    _ws2.WSACleanup()
end

return m