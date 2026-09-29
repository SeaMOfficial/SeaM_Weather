--- SeaM_Weather :: configuration

Config = {}

--- Weather ------------------------------------------------------------------
Config.Weather = {
    --- Turn this off and the resource only manages time.
    Enabled = true,

    --- The weather everywhere that is not inside a zone, as odds.
    ---
    --- The numbers are weights, not percentages, so they do not have to add up
    --- to anything. Writing them as percentages just makes them easy to read.
    ---
    --- This is a flat roll each cycle, not a progression: sun can follow a
    --- storm. If you want weather that feels like it builds, give the
    --- in-between types (CLOUDS, OVERCAST, CLEARING) most of the weight and
    --- leave the extremes small.
    Global = {
        { 'EXTRASUNNY', 20 },
        { 'CLEAR',      25 },
        { 'CLOUDS',     20 },
        { 'OVERCAST',   15 },
        { 'CLEARING',   10 },
        { 'RAIN',        7 },
        { 'THUNDER',     3 },
    },

    --- What the server starts on before the first roll.
    Start = 'CLEAR',

    --- Real-world minutes between rolls. Zones can set their own `duration`.
    Duration = 20,

    --- How long the sky takes to change, in seconds. The game blends between
    --- the two types over this window, so a storm rolls in rather than
    --- appearing between one frame and the next.
    Transition = 45,

    --- How long the sky takes to change when you cross a zone border. Shorter
    --- than a full transition: walking into a valley should not take as long
    --- as a weather front arriving.
    ZoneBlend = 8,

    --- False stops the rolls. Admins keep manual control either way.
    Dynamic = true,
}

--- Zones --------------------------------------------------------------------
--- Areas of the map with their own weather.
---
--- Worth understanding before you configure this: GTA's weather is a single
--- global render state, so what a zone actually does is tell *your client* to
--- render something else while you are inside it. Two players standing
--- together always see the same sky, because they are in the same zone, and
--- the roll happens once on the server rather than once per player. A player
--- in the storm zone sees a storm; one outside it does not.
---
--- Each zone needs:
---   coords    the centre
---   radius    metres, or use `size` for a box
---   weather   the odds, as { 'TYPE', weight } pairs
---
--- Optional:
---   id                a stable name for /zoneweather. Defaults to zone1, zone2...
---   label             what /whereami reports
---   duration          minutes between this zone's own rolls
---   size / rotation   a rotated box instead of a sphere, as vector3 and degrees
---   timecycle         a timecycle modifier applied on entry
---   extraTimecycle    a second one layered on top
---   timecycleStrength 0 to 1
---
--- Zones are tested in order and the first match wins, so put small zones
--- above the large ones they sit inside.

Config.Zones = {

    {
        id = 'paleto',
        label = 'Paleto Bay',
        coords = vector3(-275.0, 6635.0, 7.0),
        radius = 200.0,
        --- Damp and misty up the coast.
        weather = {
            { 'FOGGY',    35 },
            { 'OVERCAST', 25 },
            { 'RAIN',     20 },
            { 'CLOUDS',   20 },
        },
        timecycle = 'int_extlight_small_fog',
        timecycleStrength = 0.4,
    },
}

--- Time ---------------------------------------------------------------------
Config.Time = {
    Enabled = true,

    --- Real seconds per in-game minute. 2 gives a 48-minute day, which is the
    --- usual roleplay pace. Set 60 for real time.
    SecondsPerMinute = 2,

    --- Where the clock starts after a restart.
    StartHour = 8,
    StartMinute = 0,

    --- Stops the clock. Admins can toggle this at runtime with /freezetime.
    Frozen = false,

    --- How often the server re-sends the time. Clients keep their own clock
    --- ticking between these, so this is a correction rather than the thing
    --- driving the time.
    SyncSeconds = 30,
}

--- Timecycles ---------------------------------------------------------------
--- A weather type changes the sky. A timecycle modifier changes the grade: fog
--- density, light colour, contrast. It is what makes a zone feel different
--- rather than just having different clouds over it.
---
--- An unknown modifier name is ignored by the game, so a typo costs you the
--- effect and nothing else.
Config.Timecycles = {
    Enabled = true,

    --- Default blend strength, 0 to 1, when a zone does not set its own.
    Strength = 1.0,
}

--- Admin --------------------------------------------------------------------
Config.Admin = {
    --- Permission group needed for the weather and time commands. Uses
    --- SeaM_Core's groups.
    Permission = 'admin',

    --- Announce weather changes to everyone who is online.
    Announce = true,
}

--- Blackout -----------------------------------------------------------------
Config.Blackout = {
    --- Whether vehicle headlights still work during a blackout.
    AffectsVehicles = false,
}
