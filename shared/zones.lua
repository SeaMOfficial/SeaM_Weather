Zones = {}

local list = {}

for index, zone in ipairs(Config.Zones) do
    zone.id = zone.id or ('zone%d'):format(index)
    zone.label = zone.label or zone.id
    zone.radius = tonumber(zone.radius) or 100.0

    local total = 0
    local odds = {}

    for _, entry in ipairs(zone.weather or {}) do
        local name, weight = entry[1], tonumber(entry[2]) or 0

        if not Weathers[name] then
            print(('[SeaM_Weather] zone "%s" lists an unknown weather "%s"; ignored')
                :format(zone.label, tostring(name)))
        elseif weight > 0 then
            total = total + weight
            odds[#odds + 1] = { name = name, weight = weight, ceiling = total }
        end
    end

    zone.odds = odds
    zone.total = total

    if total < 1 then
        print(('[SeaM_Weather] zone "%s" has no usable weather odds; it will follow the global weather')
            :format(zone.label))
    end

    list[#list + 1] = zone
end

function Zones.list() return list end

function Zones.get(id)
    for _, zone in ipairs(list) do
        if zone.id == id then return zone end
    end
end

local function inside(zone, coords)
    if zone.size then
        local offset = coords - zone.coords
        local heading = math.rad(-(zone.rotation or 0.0))
        local cos, sin = math.cos(heading), math.sin(heading)

        local x = offset.x * cos - offset.y * sin
        local y = offset.x * sin + offset.y * cos

        return math.abs(x) <= zone.size.x / 2
           and math.abs(y) <= zone.size.y / 2
           and math.abs(offset.z) <= zone.size.z / 2
    end

    return #(coords - zone.coords) <= zone.radius
end

function Zones.at(coords)
    for _, zone in ipairs(list) do
        if inside(zone, coords) then return zone end
    end
end

function Zones.roll(odds, total)
    if not odds or total < 1 then return nil end

    local pick = math.random() * total

    for _, entry in ipairs(odds) do
        if pick <= entry.ceiling then return entry.name end
    end

    return odds[#odds].name
end
