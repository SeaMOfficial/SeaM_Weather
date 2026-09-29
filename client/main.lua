local setRain = rawget(_G, 'SetRain') or rawget(_G, 'SetRainFxIntensity') or rawget(_G, 'SetRainLevel')

local state = {
    global = Config.Weather.Start,
    zones = {},
    applied = nil,
    zoneRef = nil,
    timecycle = nil,
    blackout = false,
    hour = Config.Time.StartHour,
    minute = Config.Time.StartMinute,
    frozen = Config.Time.Frozen,
    ready = false,
}

local function effects(weather)
    local def = Weathers[weather] or Weathers.CLEAR

    if setRain then pcall(setRain, def.rain or 0.0) end

    SetWind(def.wind or 1.0)
    SetWindSpeed(def.wind or 1.0)
    SetWindDirection(GetRandomFloatInRange(0.0, 6.2))

    SetForceVehicleTrails(def.snow == true)
    SetForcePedFootstepsTracks(def.snow == true)
end

local function applyTimecycle(zone)
    if state.timecycle then
        ClearTimecycleModifier()
        ClearExtraTimecycleModifier()
        state.timecycle = nil
    end

    if not zone or not Config.Timecycles.Enabled then return end
    if not zone.timecycle and not zone.extraTimecycle then return end

    if zone.timecycle then
        SetTimecycleModifier(zone.timecycle)
        SetTimecycleModifierStrength(zone.timecycleStrength or Config.Timecycles.Strength)
    end

    if zone.extraTimecycle then
        SetExtraTimecycleModifier(zone.extraTimecycle)
    end

    state.timecycle = zone.timecycle or zone.extraTimecycle
end

local function applyWeather(weather, transition)
    if not Weathers[weather] then weather = 'CLEAR' end

    ClearOverrideWeather()
    ClearWeatherTypePersist()

    if transition and transition > 0 then
        SetWeatherTypeOvertimePersist(weather, transition + 0.0)

        SetTimeout(math.floor(transition * 1000) + 500, function()
            if state.applied ~= weather then return end
            SetWeatherTypeNowPersist(weather)
            SetWeatherTypePersist(weather)
        end)
    else
        SetWeatherTypeNowPersist(weather)
        SetWeatherTypePersist(weather)
        SetOverrideWeather(weather)
    end

    state.applied = weather
    effects(weather)

    TriggerEvent('SeaM_Weather:client:changed', weather, state.zoneRef and state.zoneRef.label or nil)
end

local function resolve(coords)
    local zone = Zones.at(coords)
    if not zone then return state.global, nil end

    return state.zones[zone.id] or state.global, zone
end

local function refresh(transition)
    if not Config.Weather.Enabled then return end

    local weather, zone = resolve(GetEntityCoords(PlayerPedId()))

    if weather == state.applied and zone == state.zoneRef then return end

    local moved = zone ~= state.zoneRef
    state.zoneRef = zone

    if moved then applyTimecycle(zone) end

    applyWeather(weather, transition or (moved and Config.Weather.ZoneBlend or Config.Weather.Transition))
end

RegisterNetEvent('SeaM_Weather:client:sync', function(payload)
    if type(payload) ~= 'table' then return end

    state.global = payload.weather or state.global
    state.zones = payload.zones or {}
    state.blackout = payload.blackout == true
    state.frozen = payload.frozen == true
    state.hour = payload.hour or state.hour
    state.minute = payload.minute or state.minute
    state.ready = true

    if Config.Time.Enabled then
        NetworkOverrideClockTime(state.hour, state.minute, 0)
    end

    SetArtificialLightsState(state.blackout)
    SetArtificialLightsStateAffectsVehicles(Config.Blackout.AffectsVehicles)

    refresh(payload.transition)
end)

RegisterNetEvent('SeaM_Weather:client:whereami', function()
    local coords = GetEntityCoords(PlayerPedId())
    local weather, zone = resolve(coords)

    local line

    if zone then
        local distance = #(coords - zone.coords)
        line = ('%s [%s] | %s | %.0fm from the centre of %.0fm')
            :format(zone.label, zone.id, weather, distance, zone.radius)
    else
        line = ('Outside every zone | %s'):format(weather)
    end

    TriggerEvent('SeaM_Core:notify', line, 'inform', 9000, 'Weather zone')
    print(('[SeaM_Weather] %s'):format(line))
    print(('[SeaM_Weather] vector3(%.1f, %.1f, %.1f)'):format(coords.x, coords.y, coords.z))
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    TriggerServerEvent('SeaM_Weather:server:request')

    while true do
        Wait(2000)
        if state.ready then refresh() end
    end
end)

CreateThread(function()
    if not Config.Time.Enabled then return end

    local step = math.max(Config.Time.SecondsPerMinute, 1) * 1000

    while true do
        Wait(step)

        if state.ready and not state.frozen then
            state.minute = state.minute + 1

            if state.minute >= 60 then
                state.minute = 0
                state.hour = (state.hour + 1) % 24
            end
        end

        if state.ready then
            NetworkOverrideClockTime(state.hour, state.minute, 0)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    ClearOverrideWeather()
    ClearWeatherTypePersist()
    NetworkClearClockTimeOverride()
    SetArtificialLightsState(false)
    SetForceVehicleTrails(false)
    SetForcePedFootstepsTracks(false)

    if state.timecycle then
        ClearTimecycleModifier()
        ClearExtraTimecycleModifier()
    end
end)

exports('GetWeather', function() return state.applied end)
exports('GetGlobalWeather', function() return state.global end)
exports('GetZone', function()
    return state.zoneRef and state.zoneRef.id or nil, state.zoneRef and state.zoneRef.label or nil
end)
exports('GetTime', function() return state.hour, state.minute end)
exports('IsBlackout', function() return state.blackout end)
exports('GetTimecycle', function() return state.timecycle end)
