--- @module server_network
--- @file src/planetlua/server/core/network.lua
--- @description Server-side TCP listener, handshake and player management.

local _net = require("src.engine.modules.network")
local _connection = require("projects.test_project.game.shared.net.connection")
local _hooks = require("src.engine.modules.hooks")
local _log = require("src.engine.core.log")

local m = {
    port = 7777,
    listener = nil,
    clients = {},
    next_id = 1,
    closed = false,
}

function m.init()
    if m.listener then return true end

    local listener, err = _net.tcp_listen(m.port)
    if not listener then error("network: failed to listen on port " .. m.port .. ": " .. tostring(err)) end

    m.listener = listener
    m.clients = {}
    m.next_id = 1
    m.closed = false

    _log.print("success", ("network listening on port %d"):format(m.port))
    return true
end

local function remove_client(client, reason)
    if client.removed then return end
    client.removed = true
    _connection.close(client.connection)

    for i = #m.clients, 1, -1 do
        if m.clients[i] == client then
            table.remove(m.clients, i)
            break
        end
    end

    if client.joined then
        _log.print("info", ("player %d left%s"):format(client.id, reason and (" (" .. tostring(reason) .. ")") or ""))
        _hooks.fire("player_left", client.id)
    end
end

local function accept_clients()
    while m.listener do
        local socket, ip, port = _net.tcp_accept(m.listener)

        if not socket then
            if ip then _log.print("error", "network accept failed: " .. tostring(ip)) end
            return
        end

        local client = {
            connection = _connection.new(socket),
            ip = ip,
            port = port,
            id = nil,
            joined = false,
            removed = false,
        }

        m.clients[#m.clients + 1] = client
        _log.print("info", ("connection accepted from %s:%d"):format(ip, port))
    end
end

local function finish_handshake(client)
    client.id = m.next_id
    m.next_id = m.next_id + 1
    client.joined = true

    _connection.send(client.connection, { type = "welcome", id = client.id })
    _log.print("success", ("player %d joined"):format(client.id))
    _hooks.fire("player_joined", client.id)
end

local function poll_client(client)
    local packets, err = _connection.receive(client.connection)

    if err then
        remove_client(client, err)
        return
    end

    for _, packet in ipairs(packets) do
        if type(packet) == "table" and not client.joined and packet.type == "hello" then
            finish_handshake(client)
        end
    end

    if client.removed then return end

    local ok, flush_err = _connection.flush(client.connection)
    if not ok then remove_client(client, flush_err) end
end

function m.update()
    if not m.listener then return end

    accept_clients()

    local snapshot = {}
    for i = 1, #m.clients do snapshot[i] = m.clients[i] end

    for i = 1, #snapshot do
        if not snapshot[i].removed then poll_client(snapshot[i]) end
    end
end

function m.list()
    local result = {}

    for i = 1, #m.clients do
        local client = m.clients[i]
        if client.joined then
            result[#result + 1] = { id = client.id, ip = client.ip, port = client.port }
        end
    end

    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

function m.send(id, packet)
    for i = 1, #m.clients do
        local client = m.clients[i]
        if client.joined and client.id == id then
            return _connection.send(client.connection, packet)
        end
    end

    return false, "unknown player " .. tostring(id)
end

function m.close()
    if m.closed then return end
    m.closed = true

    for i = #m.clients, 1, -1 do
        _connection.close(m.clients[i].connection)
        m.clients[i] = nil
    end

    if m.listener then
        _net.close(m.listener)
        m.listener = nil
    end

    _net.cleanup()
end

return m