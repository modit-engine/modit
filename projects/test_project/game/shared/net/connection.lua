--- @module connection
--- @file src/planetlua/shared/net/connection.lua
--- @description Length-prefixed TCP connection with receive buffering and send queues.

local _ffi = require("ffi")
local _net = require("src.engine.modules.network")

local m = {}

local HEADER_SIZE = 4
local MAX_PACKET_SIZE = 1024 * 1024

local function pack_u32(value)
    return string.char(
        value % 256,
        math.floor(value / 256) % 256,
        math.floor(value / 65536) % 256,
        math.floor(value / 16777216) % 256
    )
end

local function unpack_u32(data)
    local a, b, c, d = data:byte(1, 4)

    return
        a +
        b * 256 +
        c * 65536 +
        d * 16777216
end

--- Creates a framed connection around a TCP socket
--- @param socket table Raw network socket
--- @return table connection
function m.new(socket)
    return {
        socket = socket,
        receive_buffer = "",
        send_buffer = "",
        closed = false,
    }
end

--- Queues a Lua value as a framed packet
--- @param connection table
--- @param value any
--- @return boolean success
--- @return string|nil error
function m.send(connection, value)
    if connection.closed then
        return false, "connection closed"
    end

    local data, err = _net.serializer.encode(value)

    if not data then
        return false, err
    end

    if #data > MAX_PACKET_SIZE then
        return false, "packet too large"
    end

    connection.send_buffer =
        connection.send_buffer ..
        pack_u32(#data) ..
        data

    return true
end

--- Flushes queued bytes to the socket
--- @param connection table
--- @return boolean success
--- @return string|nil error
function m.flush(connection)
    if connection.closed then
        return false, "connection closed"
    end

    if #connection.send_buffer == 0 then
        return true
    end

    local sent, err = _net.tcp_send(connection.socket, connection.send_buffer)

    if not sent then
        connection.closed = true
        return false, err
    end

    if sent > 0 then
        connection.send_buffer = connection.send_buffer:sub(sent + 1)
    end

    return true
end

--- Polls the socket and returns all complete packets
--- @param connection table
--- @return table packets
--- @return string|nil error
function m.receive(connection)
    if connection.closed then
        return {}, "connection closed"
    end

    local data, err = _net.tcp_recv(connection.socket)

    if not data then
        connection.closed = true
        return {}, err
    end

    if #data > 0 then
        connection.receive_buffer =
            connection.receive_buffer .. data
    end

    local packets = {}

    while #connection.receive_buffer >= HEADER_SIZE do
        local size = unpack_u32(connection.receive_buffer)

        if size > MAX_PACKET_SIZE then
            connection.closed = true
            return packets, "packet too large"
        end

        if #connection.receive_buffer < HEADER_SIZE + size then
            break
        end

        local payload = connection.receive_buffer:sub(
            HEADER_SIZE + 1,
            HEADER_SIZE + size
        )

        connection.receive_buffer =
            connection.receive_buffer:sub(HEADER_SIZE + size + 1)

        local value, decode_err = _net.serializer.decode(payload)

        if decode_err then
            connection.closed = true
            return packets, decode_err
        end

        packets[#packets + 1] = value
    end

    return packets
end

--- Closes the connection
--- @param connection table
function m.close(connection)
    if connection.closed then return end

    connection.closed = true
    _net.close(connection.socket)
end

return m