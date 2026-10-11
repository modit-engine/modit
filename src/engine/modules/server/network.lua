--- @module network
--- @file src/engine/modules/network.lua
--- @description Engine network module. Raw TCP sockets plus length-prefixed connections that carry serialized Lua values.

--- @section Imports

local _backend = require("src.engine.backend").network
local _serializer = require("src.engine.core.net.serializer")

--- @section Constants

local HEADER_SIZE = 4
local MAX_PACKET_SIZE = 1024 * 1024

--- @section Module

local m = { serializer = _serializer, connection = {} }

local _connection = m.connection

--- @section Helpers

--- Packs an unsigned 32-bit integer into 4 little-endian bytes
--- @param value number Integer to pack
--- @return string bytes 4 byte string
local function pack_u32(value)
    return string.char(
        value % 256,
        math.floor(value / 256) % 256,
        math.floor(value / 65536) % 256,
        math.floor(value / 16777216) % 256
    )
end

--- Reads an unsigned 32-bit integer from the first 4 bytes of a string
--- @param data string Buffer holding at least 4 bytes
--- @return number value Unpacked integer
local function unpack_u32(data)
    local a, b, c, d = data:byte(1, 4)
    return a + b * 256 + c * 65536 + d * 16777216
end

--- @section Sockets

--- Starts listening for TCP connections
--- @param port number Port to listen on
--- @return table|nil listener Listener handle
--- @return string|nil error Error message on failure
function m.tcp_listen(port)
    return _backend.tcp_listen(port)
end

--- Accepts one pending connection, if any
--- @param listener table Listener handle
--- @return table|nil socket Accepted socket, nil when nothing is pending
--- @return string|nil ip Client IP, or an error message when accept failed
--- @return number|nil port Client port
function m.tcp_accept(listener)
    return _backend.tcp_accept(listener)
end

--- Begins a non-blocking connection to a server
--- @param host string Server host or IP
--- @param port number Server port
--- @return table|nil socket Connecting socket
--- @return string|nil error Error message on failure
function m.tcp_connect(host, port)
    return _backend.tcp_connect(host, port)
end

--- Polls the state of a connecting socket
--- @param socket table Socket handle
--- @return string state "connecting", "connected" or "failed"
--- @return string|nil error Error message when failed
function m.tcp_status(socket)
    return _backend.tcp_status(socket)
end

--- Sends raw bytes over a socket
--- @param socket table Socket handle
--- @param data string Bytes to send
--- @return number|nil sent Number of bytes sent
--- @return string|nil error Error message on failure
function m.tcp_send(socket, data)
    return _backend.tcp_send(socket, data)
end

--- Receives any raw bytes waiting on a socket
--- @param socket table Socket handle
--- @return string|nil data Received bytes, empty when nothing is waiting
--- @return string|nil error Error message on failure or disconnect
function m.tcp_recv(socket)
    return _backend.tcp_recv(socket)
end

--- Closes a socket or listener
--- @param socket table Socket or listener handle
function m.close(socket)
    return _backend.close(socket)
end

--- Releases network backend mods, call once on shutdown
function m.cleanup()
    return _backend.cleanup()
end

--- @section Connections

--- Creates a framed connection around a TCP socket
--- @param socket table Raw network socket
--- @return table connection Connection state
function _connection.new(socket)
    return {
        socket = socket,
        receive_buffer = "",
        send_buffer = "",
        closed = false,
    }
end

--- Queues a Lua value as a framed packet
--- @param connection table Connection state
--- @param value any Value to serialize and queue
--- @return boolean success True if queued
--- @return string|nil error Error message on failure
function _connection.send(connection, value)
    if connection.closed then
        return false, "connection closed"
    end

    local data, err = _serializer.encode(value)
    if not data then
        return false, err
    end

    if #data > MAX_PACKET_SIZE then
        return false, "packet too large"
    end

    connection.send_buffer = connection.send_buffer .. pack_u32(#data) .. data
    return true
end

--- Flushes queued bytes to the socket
--- @param connection table Connection state
--- @return boolean success True if flushed without a socket error
--- @return string|nil error Error message on failure
function _connection.flush(connection)
    if connection.closed then
        return false, "connection closed"
    end

    if #connection.send_buffer == 0 then
        return true
    end

    local sent, err = _backend.tcp_send(connection.socket, connection.send_buffer)
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
--- @param connection table Connection state
--- @return table packets Array of decoded values
--- @return string|nil error Error message on disconnect or malformed data
function _connection.receive(connection)
    if connection.closed then
        return {}, "connection closed"
    end

    local data, err = _backend.tcp_recv(connection.socket)
    if not data then
        connection.closed = true
        return {}, err
    end

    if #data > 0 then
        connection.receive_buffer = connection.receive_buffer .. data
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

        local payload = connection.receive_buffer:sub(HEADER_SIZE + 1, HEADER_SIZE + size)
        connection.receive_buffer = connection.receive_buffer:sub(HEADER_SIZE + size + 1)

        local value, decode_err = _serializer.decode(payload)
        if decode_err then
            connection.closed = true
            return packets, decode_err
        end

        packets[#packets + 1] = value
    end

    return packets
end

--- Closes the connection and its socket
--- @param connection table Connection state
function _connection.close(connection)
    if connection.closed then return end

    connection.closed = true
    _backend.close(connection.socket)
end

return m