ESX = exports['es_extended']:getSharedObject()
local boomboxes = {}
local usedNetIds = {}

ESX.RegisterUsableItem('speaker', function(source)
    TriggerClientEvent('esx_boombox:useItem', source)
end)

local function GenerateNetId()
    local netId
    repeat
        netId = math.random(100000, 999999)
    until not usedNetIds[netId]
    usedNetIds[netId] = true
    return netId
end

RegisterServerEvent('esx_boombox:updateCoords')
AddEventHandler('esx_boombox:updateCoords', function(netId, coords)
    local src = source
    local box = boomboxes[netId]
    if not box then return end
    if box.owner ~= src and not box.public then return end

    box.coords = coords
    TriggerClientEvent('esx_boombox:updateCoords', -1, netId, coords)
end)

RegisterNetEvent('esx_boombox:updatePublic')
AddEventHandler('esx_boombox:updatePublic', function(netId, isPublic)
    if boomboxSounds[netId] then
        boomboxSounds[netId].public = isPublic
        local entity = placedBoomboxes[netId]
        if DoesEntityExist(entity) then
            setupTargetOptions(netId, entity)
        end
    end
end)

RegisterServerEvent('esx_boombox:serverPlaceBoombox')
AddEventHandler('esx_boombox:serverPlaceBoombox', function(coords, heading)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local netId = GenerateNetId()
    boomboxes[netId] = {
        owner = src,
        coords = coords,
        heading = heading,
        public = false,
        volume = 0.4,
        range = 15,
        playing = false,
        url = nil
    }

    xPlayer.removeInventoryItem('speaker', 1)
    TriggerClientEvent('esx_boombox:clientPlaceBoombox', src, netId, coords, heading)
end)

RegisterServerEvent('esx_boombox:playMusic')
AddEventHandler('esx_boombox:playMusic', function(netId, url)
    local src = source
    local box = boomboxes[netId]
    if not box then return end
    if box.owner ~= src and not box.public then return end

    box.playing = true
    box.url = url
    TriggerClientEvent('esx_boombox:playMusic', -1, netId, url, box.volume, box.range)
end)

RegisterServerEvent('esx_boombox:changeVolume')
AddEventHandler('esx_boombox:changeVolume', function(netId, volume)
    local src = source
    local box = boomboxes[netId]
    if not box then return end
    if box.owner ~= src and not box.public then return end

    box.volume = volume / 100
    TriggerClientEvent('esx_boombox:updateVolume', -1, netId, box.volume)
end)

RegisterServerEvent('esx_boombox:changeRange')
AddEventHandler('esx_boombox:changeRange', function(netId, range)
    local src = source
    local box = boomboxes[netId]
    if not box then return end
    if box.owner ~= src and not box.public then return end

    box.range = range
    TriggerClientEvent('esx_boombox:updateRange', -1, netId, range)
end)

RegisterServerEvent('esx_boombox:togglePublic')
AddEventHandler('esx_boombox:togglePublic', function(netId)
    local src = source
    local box = boomboxes[netId]
    if not box or box.owner ~= src then return end

    box.public = not box.public
    TriggerClientEvent('esx_boombox:updatePublic', -1, netId, box.public)
end)

RegisterServerEvent('esx_boombox:takeBack')
AddEventHandler('esx_boombox:takeBack', function(netId)
    local src = source
    local box = boomboxes[netId]
    if not box or box.owner ~= src then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        xPlayer.addInventoryItem('speaker', 1)
        TriggerClientEvent('esx_boombox:removeBoombox', -1, netId)
        boomboxes[netId] = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for netId, box in pairs(boomboxes) do
        if box.owner == src then
            TriggerClientEvent('esx_boombox:removeBoombox', -1, netId)
            boomboxes[netId] = nil
        end
    end
end)

ESX.RegisterServerCallback('esx_boombox:canInteract', function(source, cb, netId)
    local box = boomboxes[netId]
    if box then
        cb(box.public or box.owner == source)
    else
        cb(false)
    end
end)
