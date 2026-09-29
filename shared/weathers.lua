--- Every weather type the game accepts, with the effects that go with it.
---
--- `rain` drives the wet-road and rainfall intensity, 0 to 1.
--- `wind` is the wind speed the game is pushed towards.
--- `snow` turns on footprint and tyre tracks.
---
--- Anything not listed here is rejected, so a typo in a zone's odds is caught
--- at boot instead of quietly never happening.

Weathers = {
    EXTRASUNNY = { rain = 0.0, wind = 0.4 },
    CLEAR      = { rain = 0.0, wind = 0.6 },
    NEUTRAL    = { rain = 0.0, wind = 0.7 },
    SMOG       = { rain = 0.0, wind = 0.3 },
    FOGGY      = { rain = 0.0, wind = 0.2 },
    OVERCAST   = { rain = 0.0, wind = 1.2 },
    CLOUDS     = { rain = 0.0, wind = 0.9 },
    CLEARING   = { rain = 0.1, wind = 1.0 },
    RAIN       = { rain = 0.6, wind = 1.8 },
    THUNDER    = { rain = 1.0, wind = 3.2 },
    SNOW       = { rain = 0.3, wind = 1.4, snow = true },
    SNOWLIGHT  = { rain = 0.2, wind = 1.0, snow = true },
    BLIZZARD   = { rain = 0.5, wind = 4.0, snow = true },
    XMAS       = { rain = 0.3, wind = 1.2, snow = true },
    HALLOWEEN  = { rain = 0.0, wind = 1.0 },
}
