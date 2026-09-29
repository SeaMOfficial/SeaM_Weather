local Core = exports.SeaM_Core:GetCoreObject()
local SeaM = exports.SeaM_Core

local state = {
    global = Config.Weather.Start,
    dynamic = Config.Weather.Dynamic,
    blackout = false,
    hour = Config.Time.StartHour,
    minute = Config.Time.StartMinute,
    frozen = Config.Time.Frozen,
    zones = {},
}

local schedule = { global = 0, zones = {} }

local function valid(weather)
    return type(weather) == 'string' and Weathers[weather:upper()] and weather:upper() or nil
end

local function snapshot(transition)
    return {
        weather    = state.global,
        zones      = state.zones,
        blackout   = state.blackout,
        hour       = state.hour,
        minute     = state.minute,
        frozen     = state.frozen,
        transition = transition or 0,
    }
end

local function broadcast(target, transition)
    TriggerClientEvent('SeaM_Weather:client:sync', target or -1, snapshot(transition))
end

local function rollGlobal()
    local weather = Zones.roll(state.globalOdds, state.globalTotal)
    if not weather then return false end

    state.global = weather
    return true
end

local function rollZone(zone)
    if zone.total < 1 then return false end

    local weather = Zones.roll(zone.odds, zone.total)
    if not weather or weather == state.zones[zone.id] then return false end

    state.zones[zone.id] = weather
    return true
end

do
    local total = 0
    local odds = {}

    for _, entry in ipairs(Config.Weather.Global) do
        local name, weight = entry[1], tonumber(entry[2]) or 0

        if not Weathers[name] then
            print(('[SeaM_Weather] Config.Weather.Global lists an unknown weather "%s"; ignored')
                :format(tostring(name)))
        elseif weight > 0 then
            total = total + weight
            odds[#odds + 1] = { name = name, weight = weight, ceiling = total }
        end
    end

    state.globalOdds = odds
    state.globalTotal = total

    if total < 1 then
        print('[SeaM_Weather] Config.Weather.Global has no usable odds; the weather will never change on its own')
    end

    for _, zone in ipairs(Zones.list()) do
        if zone.total > 0 then state.zones[zone.id] = Zones.roll(zone.odds, zone.total) end
    end
end

CreateThread(function()
    if not Config.Weather.Enabled then return end

    local now = GetGameTimer()
    schedule.global = now + (math.max(Config.Weather.Duration, 1) * 60000)

    for _, zone in ipairs(Zones.list()) do
        schedule.zones[zone.id] = now + (math.max(zone.duration or Config.Weather.Duration, 1) * 60000)
    end

    while true do
        Wait(1000)

        if state.dynamic then
            now = GetGameTimer()
            local changed = false

            if now >= schedule.global then
                schedule.global = now + (math.max(Config.Weather.Duration, 1) * 60000)
                if rollGlobal() then changed = true end
            end

            for _, zone in ipairs(Zones.list()) do
                if now >= (schedule.zones[zone.id] or 0) then
                    schedule.zones[zone.id] = now
                        + (math.max(zone.duration or Config.Weather.Duration, 1) * 60000)
                    if rollZone(zone) then changed = true end
                end
            end

            if changed then
                broadcast(-1, Config.Weather.Transition)
                TriggerEvent('SeaM_Weather:server:changed', state.global, state.zones)
            end
        end
    end
end)

CreateThread(function()
    if not Config.Time.Enabled then return end

    local step = math.max(Config.Time.SecondsPerMinute, 1) * 1000

    while true do
        Wait(step)

        if not state.frozen then
            state.minute = state.minute + 1

            if state.minute >= 60 then
                state.minute = 0
                state.hour = (state.hour + 1) % 24
            end
        end
    end
end)

CreateThread(function()
    if not Config.Time.Enabled then return end

    local interval = math.max(Config.Time.SyncSeconds, 5) * 1000

    while true do
        Wait(interval)
        broadcast(-1, 0)
    end
end)

RegisterNetEvent('SeaM_Weather:server:request', function()
    broadcast(source, 0)
end)

AddEventHandler('SeaM_Core:player:loaded', function(source)
    broadcast(source, 0)
end)

local Commands = Core.Commands
local permission = Config.Admin.Permission

Commands.register('weather', {
    help = 'Set the weather outside the zones, or "dynamic" to resume rolling',
    permission = permission,
    params = {
        { name = 'type', type = 'string', help = 'CLEAR, RAIN, THUNDER, ... or dynamic' },
    },
    handler = function(source, args)
        local requested = args.type:upper()

        if requested == 'DYNAMIC' or requested == 'AUTO' then
            state.dynamic = true
            return SeaM:Notify(source, 'Weather is rolling again.', 'success')
        end

        if requested == 'FREEZE' or requested == 'STATIC' then
            state.dynamic = false
            return SeaM:Notify(source, ('Weather held at %s.'):format(state.global), 'success')
        end

        if not valid(requested) then
            return SeaM:Notify(source, ('There is no weather called "%s".'):format(args.type), 'error')
        end

        state.dynamic = false
        state.global = requested
        broadcast(-1, Config.Weather.Transition)

        if Config.Admin.Announce then
            SeaM:Notify(-1, ('The weather is turning to %s.'):format(requested:lower()), 'inform')
        end

        SeaM:Notify(source, ('Weather set to %s. Rolling is paused.'):format(requested), 'success')
        Core.Log.audit('admin', 'Weather changed', ('**%s** set the weather to `%s`')
            :format(GetPlayerName(source) or 'console', requested))
    end,
})

Commands.register('zoneweather', {
    help = "Set one zone's weather",
    permission = permission,
    params = {
        { name = 'zone', type = 'string', help = 'Zone id, see /weatherzones' },
        { name = 'type', type = 'string', help = 'Weather type, or "roll" to re-roll it' },
    },
    handler = function(source, args)
        local zone = Zones.get(args.zone)
        if not zone then
            return SeaM:Notify(source, ('There is no zone called "%s".'):format(args.zone), 'error')
        end

        if args.type:upper() == 'ROLL' then
            rollZone(zone)
            broadcast(-1, Config.Weather.Transition)
            return SeaM:Notify(source, ('%s rolled to %s.')
                :format(zone.label, state.zones[zone.id] or 'nothing'), 'success')
        end

        local requested = valid(args.type)
        if not requested then
            return SeaM:Notify(source, ('There is no weather called "%s".'):format(args.type), 'error')
        end

        state.zones[zone.id] = requested
        broadcast(-1, Config.Weather.Transition)

        SeaM:Notify(source, ('%s set to %s.'):format(zone.label, requested), 'success')
        Core.Log.audit('admin', 'Zone weather changed', ('**%s** set `%s` to `%s`')
            :format(GetPlayerName(source) or 'console', zone.label, requested))
    end,
})

Commands.register('nextweather', {
    help = 'Roll the global weather and every zone now',
    permission = permission,
    handler = function(source)
        rollGlobal()
        for _, zone in ipairs(Zones.list()) do rollZone(zone) end

        broadcast(-1, Config.Weather.Transition)
        SeaM:Notify(source, ('Rolled. It is %s outside the zones.'):format(state.global), 'success')
    end,
})

Commands.register('time', {
    help = 'Set the time of day',
    permission = permission,
    params = {
        { name = 'hour',   type = 'integer', help = '0 to 23' },
        { name = 'minute', type = 'integer', help = '0 to 59', optional = true, default = 0 },
    },
    handler = function(source, args)
        if args.hour < 0 or args.hour > 23 or args.minute < 0 or args.minute > 59 then
            return SeaM:Notify(source, 'That is not a valid time.', 'error')
        end

        state.hour, state.minute = args.hour, args.minute
        broadcast(-1, 0)

        SeaM:Notify(source, ('Clock set to %02d:%02d.'):format(args.hour, args.minute), 'success')
        Core.Log.audit('admin', 'Time changed', ('**%s** set the clock to `%02d:%02d`')
            :format(GetPlayerName(source) or 'console', args.hour, args.minute))
    end,
})

Commands.register('freezetime', {
    help = 'Stop or restart the clock',
    permission = permission,
    handler = function(source)
        state.frozen = not state.frozen
        broadcast(-1, 0)

        SeaM:Notify(source, state.frozen
            and ('Clock stopped at %02d:%02d.'):format(state.hour, state.minute)
            or 'Clock running again.', 'success')
    end,
})

Commands.register('blackout', {
    help = 'Cut the power across the map',
    permission = permission,
    handler = function(source)
        state.blackout = not state.blackout
        broadcast(-1, 0)

        SeaM:Notify(source, state.blackout and 'Blackout on.' or 'Power restored.', 'success')
        Core.Log.audit('admin', 'Blackout', ('**%s** turned the power %s')
            :format(GetPlayerName(source) or 'console', state.blackout and 'off' or 'on'), 'warn')
    end,
})

Commands.register('whereami', {
    help = 'Show which weather zone you are standing in',
    permission = permission,
    handler = function(source)
        if source == 0 then return end
        TriggerClientEvent('SeaM_Weather:client:whereami', source)
    end,
})

Commands.register('weatherzones', {
    help = 'List the configured weather zones and what each is doing',
    permission = permission,
    consoleOnly = true,
    handler = function()
        local list = Zones.list()
        print(('--- %d weather zone(s), global is %s ---'):format(#list, state.global))

        for _, zone in ipairs(list) do
            local odds = {}
            for _, entry in ipairs(zone.odds) do
                odds[#odds + 1] = ('%s %d%%'):format(entry.name,
                    math.floor((entry.weight / zone.total) * 100 + 0.5))
            end

            print(('  %-14s %-16s now %-11s [%s]'):format(
                zone.id, zone.label, state.zones[zone.id] or 'global',
                table.concat(odds, ', ')))
        end
    end,
})

exports('GetWeather', function() return state.global end)
exports('GetZoneWeather', function(id) return state.zones[id] end)
exports('GetTime', function() return state.hour, state.minute end)
exports('IsFrozen', function() return state.frozen end)
exports('IsBlackout', function() return state.blackout end)
exports('IsDynamic', function() return state.dynamic end)
exports('GetState', function() return snapshot(0) end)

exports('SetWeather', function(weather, transition)
    local requested = valid(weather)
    if not requested then return false end

    state.dynamic = false
    state.global = requested
    broadcast(-1, transition or Config.Weather.Transition)
    return true
end)

exports('SetZoneWeather', function(id, weather, transition)
    local zone = Zones.get(id)
    local requested = valid(weather)
    if not zone or not requested then return false end

    state.zones[zone.id] = requested
    broadcast(-1, transition or Config.Weather.Transition)
    return true
end)

exports('SetTime', function(hour, minute)
    state.hour = math.floor(tonumber(hour) or 0) % 24
    state.minute = math.floor(tonumber(minute) or 0) % 60
    broadcast(-1, 0)
    return true
end)

exports('SetDynamic', function(value)
    state.dynamic = value ~= false
    return true
end)

exports('FreezeTime', function(value)
    state.frozen = value ~= false
    broadcast(-1, 0)
    return true
end)

exports('SetBlackout', function(value)
    state.blackout = value ~= false
    broadcast(-1, 0)
    return true
end)
