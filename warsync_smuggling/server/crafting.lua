-- Crafting tables (admin placed, saved to JSON) + server-validated crafting.
local Tables = {}   -- [id] = { id, x, y, z, h, static }
local Crafting = {} -- [src] = { item, time, startedAt, tableId }
local nextId = 1
local resource = GetCurrentResourceName()

local CraftItems = {}
for _, it in ipairs(Config.Items) do CraftItems[it.name] = it end

local function save()
    local list = {}
    for _, t in pairs(Tables) do
        if not t.static then list[#list + 1] = { x = t.x, y = t.y, z = t.z, h = t.h } end
    end
    SaveResourceFile(resource, Config.Table.saveFile, json.encode(list, { indent = true }), -1)
end

local function addTable(x, y, z, h, static)
    local id = nextId
    nextId = nextId + 1
    Tables[id] = { id = id, x = x, y = y, z = z, h = h or 0.0, static = static or nil }
    return id
end

local function broadcast(target)
    TriggerClientEvent('wsm:tables:sync', target or -1, Tables)
end

CreateThread(function()
    for _, v in ipairs(Config.Table.staticLocations) do addTable(v.x, v.y, v.z, v.w, true) end
    local raw = LoadResourceFile(resource, Config.Table.saveFile)
    local ok, data = pcall(json.decode, raw or '[]')
    if ok and type(data) == 'table' then
        for _, t in ipairs(data) do addTable(t.x, t.y, t.z, t.h) end
    end
    broadcast()
end)

RegisterNetEvent('wsm:tables:request', function()
    broadcast(source)
end)

-- /smuggletable add | remove | list
RegisterCommand(Config.Table.command, function(src, args)
    if not WSM.IsAdmin(src) then return WSM.Notify(src, 'You are not allowed to do that.', 'error') end
    local action = args[1]
    if src == 0 and action ~= 'list' then return print('Use this command in game.') end

    if action == 'add' then
        local ped = GetPlayerPed(src)
        local c = GetEntityCoords(ped)
        addTable(c.x, c.y, c.z - 1.0, GetEntityHeading(ped))
        save(); broadcast()
        WSM.Notify(src, 'Crafting table placed and saved.', 'success', 'Workbench')
    elseif action == 'remove' then
        local c = WSM.Coords(src)
        local best, bestDist
        for id, t in pairs(Tables) do
            local d = #(vector3(t.x, t.y, t.z) - c)
            if d < 4.0 and (not bestDist or d < bestDist) then best, bestDist = id, d end
        end
        if not best then return WSM.Notify(src, 'No crafting table within 4m.', 'error') end
        if Tables[best].static then return WSM.Notify(src, 'This table is defined in config.lua.', 'error') end
        Tables[best] = nil
        save(); broadcast()
        WSM.Notify(src, 'Crafting table removed.', 'success', 'Workbench')
    elseif action == 'list' then
        local n = 0
        for id, t in pairs(Tables) do
            n = n + 1
            print(('[%d] %.2f %.2f %.2f%s'):format(id, t.x, t.y, t.z, t.static and ' (config)' or ''))
        end
        if src ~= 0 then WSM.Notify(src, n .. ' crafting table(s). See F8 / server console.', 'info') end
    else
        WSM.Notify(src, ('Usage: /%s add | remove | list'):format(Config.Table.command), 'info')
    end
end, false)

local function tableDist(src, tableId)
    local t = Tables[tableId]
    local c = WSM.Coords(src)
    if not t or not c then return math.huge end
    return #(vector3(t.x, t.y, t.z) - c)
end

ESX.RegisterServerCallback('wsm:craft:start', function(src, cb, tableId, itemName)
    local it = CraftItems[itemName]
    if not it or not WSM.IsCivilian(src) or Crafting[src] then return cb(false) end
    if tableDist(src, tonumber(tableId)) > Config.Table.interactDistance + 1.5 then return cb(false) end
    Crafting[src] = { item = it.name, time = it.time, startedAt = os.time(), tableId = tonumber(tableId) }
    cb(true, it.time)
end)

ESX.RegisterServerCallback('wsm:craft:finish', function(src, cb)
    local c = Crafting[src]
    Crafting[src] = nil
    if not c then return cb(false) end
    -- 2s tolerance for network latency; anything earlier is an exploit attempt.
    if os.time() - c.startedAt < c.time - 2 then
        WSM.Log(('Player %s tried to finish a craft too early'):format(src))
        return cb(false)
    end
    if not WSM.IsCivilian(src) or tableDist(src, c.tableId) > Config.Table.cancelDistance + 1.5 then return cb(false) end
    if not WSM.Add(src, c.item, 1) then
        WSM.Notify(src, 'You cannot carry this item.', 'error')
        return cb(false)
    end
    cb(true, c.item)
end)

RegisterNetEvent('wsm:craft:cancel', function()
    Crafting[source] = nil
end)

AddEventHandler('playerDropped', function()
    Crafting[source] = nil
end)
