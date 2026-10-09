--- @module network
--- @file projects/test_project/game/client/core/network.lua
--- @description Client-side TCP connection and handshake.

--- @section Imports

local _net = require("src.engine.modules.network")
local _connection = require("projects.test_project.game.shared.net.connection")
local _log = require("src.engine.core.log")

--- @section Initialisation

local m = {
    host = "127.0.0.1",
    port = 7777,

    socket = nil,
    connection = nil,

    state = "disconnected",
    player_id = nil,
    error = nil,
}

--- @section Functions

function m.connect(host, port)
    if m.socket then
        m.close()
    end

    m.host = host or m.host
    m.port = port or m.port
    m.error = nil
    m.player_id = nil

    local socket, err = _net.tcp_connect(m.host, m.port)

    if not socket then
        m.state = "failed"
        m.error = err
        return false, err
    end

    m.socket = socket
    m.state = "connecting"

    return true
end

function m.update()
    if not m.socket then
        return
    end

    if m.state == "connecting" then
        local state, err = _net.tcp_status(m.socket)

        if state == "failed" then
            m.state = "failed"
            m.error = err
            _net.close(m.socket)
            m.socket = nil

            _log.print("error", "network connection failed: " .. tostring(err))
            return
        end

        if state == "connected" then
            m.connection = _connection.new(m.socket)
            m.state = "connected"

            _log.print("success", "connected to server")

            _connection.send(m.connection, {
                type = "hello",
            })
        end

        return
    end

    if m.state ~= "connected" then
        return
    end

    local packets, err = _connection.receive(m.connection)

    if err then
        m.state = "disconnected"
        m.error = err

        _connection.close(m.connection)
        m.connection = nil
        m.socket = nil

        _log.print("info", "server disconnected: " .. tostring(err))
        return
    end

    for _, packet in ipairs(packets) do
        if type(packet) == "table" then
            if packet.type == "welcome" then
                m.player_id = packet.id

                _log.print(
                    "success",
                    ("server assigned player id %d"):format(m.player_id)
                )

            elseif packet.type == "hello_ack" then
                -- Handshake complete.
            end
        end
    end

    local ok, flush_err = _connection.flush(m.connection)

    if not ok then
        m.state = "disconnected"
        m.error = flush_err

        _connection.close(m.connection)
        m.connection = nil
        m.socket = nil
    end
end

function m.get_state()
    return m.state
end

function m.get_player_id()
    return m.player_id
end

function m.get_error()
    return m.error
end

function m.close()
    if m.connection then
        _connection.close(m.connection)
    elseif m.socket then
        _net.close(m.socket)
    end

    m.connection = nil
    m.socket = nil
    m.state = "disconnected"
    m.player_id = nil

    _net.cleanup()
end

return m