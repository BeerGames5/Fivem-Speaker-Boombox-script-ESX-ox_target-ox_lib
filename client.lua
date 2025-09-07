ESX = nil
local placedBoomboxes = {}
local boomboxSounds = {}

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Wait(10)
    end
end)

local function playPlaceAnimation()
    local ped = PlayerPedId()
    local animDict = "amb@medic@standing@kneel@idle_a"
    local animName = "idle_a"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 0, 0, false, false, false)
    Wait(1200)
    ClearPedTasks(ped)
end

local function createBoomboxObject(coords, heading)
    local model = `prop_speaker_06`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    local ped = PlayerPedId()
    local forward = GetEntityForwardVector(ped)
    local placeCoords = vector3(
        coords.x + forward.x * 0.8,
        coords.y + forward.y * 0.8,
        coords.z
    )
    local obj = CreateObject(model, placeCoords.x, placeCoords.y, placeCoords.z, true, true, true)
    SetEntityHeading(obj, heading)
    FreezeEntityPosition(obj, true)
    PlaceObjectOnGroundProperly(obj)
    return obj
end

RegisterNetEvent('esx_boombox:updateVolume')
AddEventHandler('esx_boombox:updateVolume', function(netId, volume)
    if boomboxSounds[netId] then
        boomboxSounds[netId].baseVolume = volume
    end
end)

RegisterNetEvent('esx_boombox:updateRange')
AddEventHandler('esx_boombox:updateRange', function(netId, range)
    if boomboxSounds[netId] then
        boomboxSounds[netId].range = range
    end
end)

RegisterNetEvent('esx_boombox:useItem', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    playPlaceAnimation()
    TriggerServerEvent('esx_boombox:serverPlaceBoombox', coords, heading)
end)

RegisterNetEvent('esx_boombox:clientPlaceBoombox')
AddEventHandler('esx_boombox:clientPlaceBoombox', function(netId, coords, heading)
    local obj = createBoomboxObject(coords, heading)
    placedBoomboxes[netId] = obj

    if not boomboxSounds[netId] then
        boomboxSounds[netId] = {
            baseVolume = 0.40,
            range = 15,
            public = false,
            url = nil
        }
    end

    setupTargetOptions(netId, obj)
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

function setupTargetOptions(netId, entity)
    if not DoesEntityExist(entity) then return end
    local boxData = boomboxSounds[netId] or {}

    local function buildOptions(isOwner, isPublic)
        local options = {}

        if isOwner or isPublic then
            table.insert(options, {
                name = 'playMusic',
                icon = 'fa-solid fa-play',
                label = 'Muziek spelen',
                distance = 2.0,
                onSelect = function()
                    ESX.TriggerServerCallback('esx_boombox:canInteract', function(canInteract)
                        if not canInteract then return end
                        local input = lib.inputDialog('Muziek URL', {{type='input', label='YouTube URL', required=true}})
                        if input then
                            TriggerServerEvent('esx_boombox:playMusic', netId, input[1])
                        end
                    end, netId)
                end
            })

table.insert(options, {
    name = 'changeVolume',
    icon = 'fa-solid fa-volume-high',
    label = 'Volume wijzigen',
    distance = 2.0,
    onSelect = function()
        ESX.TriggerServerCallback('esx_boombox:canInteract', function(canInteract)
            if not canInteract then return end
            local currentVolume = boomboxSounds[netId] and boomboxSounds[netId].baseVolume or 0.4
            local input = lib.inputDialog('Volume', {{type='slider', label='Volume (%)', min=0, max=100, default=currentVolume*100}})
            if input then
                TriggerServerEvent('esx_boombox:changeVolume', netId, input[1])
            end
        end, netId)
    end
})

table.insert(options, {
    name = 'changeRange',
    icon = 'fa-solid fa-signal',
    label = 'Range aanpassen',
    distance = 2.0,
    onSelect = function()
        ESX.TriggerServerCallback('esx_boombox:canInteract', function(canInteract)
            if not canInteract then return end
            local currentRange = boomboxSounds[netId] and boomboxSounds[netId].range or 15
            local input = lib.inputDialog('Bereik', {{type='slider', label='Bereik (meters)', min=1, max=50, default=currentRange}})
            if input then
                TriggerServerEvent('esx_boombox:changeRange', netId, input[1])
            end
        end, netId)
    end
})
        end

        if isOwner then
            table.insert(options, {
                name = 'togglePublic',
                icon = isPublic and 'fa-solid fa-lock' or 'fa-solid fa-unlock',
                label = isPublic and 'Privé zetten' or 'Openbaar zetten',
                distance = 2.0,
                onSelect = function()
                    TriggerServerEvent('esx_boombox:togglePublic', netId)
                end
            })

            table.insert(options, {
                name = 'takeBack',
                icon = 'fa-solid fa-box-archive',
                label = 'Box terugnemen',
                distance = 2.0,
                onSelect = function()
                    TriggerServerEvent('esx_boombox:takeBack', netId)
                end
            })

table.insert(options, {
    name = 'pickupBoombox',
    icon = 'fa-solid fa-hand-paper',
    label = 'Op pakken',
    distance = 2.0,
    onSelect = function()
        TriggerEvent('esx_boombox:pickupBoombox', netId)
    end
})
        end

        return options
    end

    exports.ox_target:removeEntity(entity)

    ESX.TriggerServerCallback('esx_boombox:canInteract', function(canInteract)
        local playerPed = PlayerPedId()
        local playerServerId = GetPlayerServerId(PlayerId())
        local boxOwner = boxData.owner or playerServerId
        local isOwner = boxOwner == playerServerId
        local isPublic = boxData.public or false

        local options = buildOptions(isOwner, isPublic)
        exports.ox_target:addLocalEntity(entity, options)
    end, netId)
end

SetNuiFocus(false, false)

local carryingBoombox = nil

RegisterNetEvent('esx_boombox:pickupBoombox')
AddEventHandler('esx_boombox:pickupBoombox', function(netId)
    local ped = PlayerPedId()
    local entity = placedBoomboxes[netId]
    if not DoesEntityExist(entity) then return end

    RequestAnimDict('anim@heists@box_carry@')
    while not HasAnimDictLoaded('anim@heists@box_carry@') do Wait(10) end
    TaskPlayAnim(ped, 'anim@heists@box_carry@', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)

    AttachEntityToEntity(
    entity,               
    ped,                    
    GetPedBoneIndex(ped, 24818),
    -0.1, 
    0.45,  
    0.0, 
    0.0,  
    0.0,  
    180.0,
    true, 
    true,
    false,
    true,
    1,
    true
)
    carryingBoombox = {netId = netId, entity = entity}
    boomboxSounds[netId].carried = true

    blockingX = true
    lib.showTextUI('[E] Box neerzetten')
end)

Citizen.CreateThread(function()
    while true do
        Wait(0)
        if carryingBoombox then
            DisableControlAction(0, 73, true)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(0)
        if carryingBoombox then
            if IsControlJustReleased(0, 38) then
                local ped = PlayerPedId()
                local netId = carryingBoombox.netId
                local entity = carryingBoombox.entity

                DetachEntity(entity, true, true)
                FreezeEntityPosition(entity, true)
                PlaceObjectOnGroundProperly(entity)
                ClearPedTasks(ped)

                boomboxSounds[netId].carried = false
                carryingBoombox = nil

                lib.hideTextUI()

                local coords = GetEntityCoords(entity)
                TriggerServerEvent('esx_boombox:updateCoords', netId, coords)
            end
        end
    end
end)

RegisterNetEvent('esx_boombox:updateCoords')
AddEventHandler('esx_boombox:updateCoords', function(netId, coords)
    local entity = placedBoomboxes[netId]
    if DoesEntityExist(entity) then
        SetEntityCoords(entity, coords.x, coords.y, coords.z)
    end
end)

RegisterNetEvent('esx_boombox:playMusic')
AddEventHandler('esx_boombox:playMusic', function(netId, url, volume, range)
    boomboxSounds[netId] = {url=url, baseVolume=volume, range=range}

    local entity = placedBoomboxes[netId]
    if not DoesEntityExist(entity) then return end
    local coords = GetEntityCoords(entity)

    SendNUIMessage({
        action = 'play',
        netId = netId,
        url = url,
        volume = volume,
        x = coords.x,
        y = coords.y,
        z = coords.z
    })
end)

RegisterNetEvent('esx_boombox:removeBoombox')
AddEventHandler('esx_boombox:removeBoombox', function(netId)
    local entity = placedBoomboxes[netId]
    if DoesEntityExist(entity) then
        exports.ox_target:removeEntity(entity)
        DeleteEntity(entity)
        placedBoomboxes[netId] = nil
    end

    SendNUIMessage({
        action = 'stop',
        netId = netId
    })

    boomboxSounds[netId] = nil
end)

Citizen.CreateThread(function()
    while true do
        Wait(200)
        local pedCoords = GetEntityCoords(PlayerPedId())
        for netId, info in pairs(boomboxSounds) do
            local entity = placedBoomboxes[netId]
            if DoesEntityExist(entity) then
                local coords = GetEntityCoords(entity)
                local dist = #(pedCoords - coords)
                local fadeVolume = 0
                if dist <= info.range then
                    fadeVolume = info.baseVolume * (1 - dist / info.range)
                end
                SendNUIMessage({
                    action = 'volume',
                    netId = netId,
                    volume = fadeVolume,
                    x = coords.x,
                    y = coords.y,
                    z = coords.z
                })
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for netId, entity in pairs(placedBoomboxes) do
            if DoesEntityExist(entity) then DeleteEntity(entity) end
        end
    end
end)
