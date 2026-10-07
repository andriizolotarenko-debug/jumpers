-- DATA: the 55 milestones (UI-SPEC: Milestones). Heights in metres.
-- Rows marked wow are estimates, to be measured in game.
local _, ns = ...
ns = ns or {}

local Landmarks = {
  { "Durotar zeppelin tower", 20, "wow" },
  { "Statue of Liberty", 93 },
  { "Great Pyramid of Giza", 139 },
  { "Space Needle", 184 },
  { "Karazhan", 250, "wow" },
  { "Eiffel Tower", 330 },
  { "Empire State Building", 443 },
  { "Tokyo Skytree", 634 },
  { "Burj Khalifa", 828 },
  { "Teldrassil", 1100, "wow" },
  { "Ben Nevis", 1345 },
  { "Mount Hoverla", 2061 },
  { "Mount Olympus", 2918 },
  { "Mount Fuji", 3776 },
  { "Mont Blanc", 4806 },
  { "Kilimanjaro", 5895 },
  { "Aconcagua", 6961 },
  { "Mount Everest", 8849 },
  { "Airliners cruise here", 11000 },
  { "Ozone layer", 15000 },
  { "Concorde cruised here", 18000 },
  { "SR-71 Blackbird record", 25929 },
  { "Highest crewed balloon, 1961", 34668 },
  { "Highest skydive", 41420 },
  { "Highest weather balloon", 53000 },
  { "Shooting stars burn up", 75000 },
  { "Kármán line, edge of space", 100000 },
  { "Northern lights", 130000 },
  { "Lowest satellite orbits", 160000 },
  { "Sputnik 1, lowest point", 215000 },
  { "Vostok 1, first human in space", 327000 },
  { "International Space Station", 420000 },
  { "Starlink satellites", 550000 },
  { "Iridium satellites", 780000 },
  { "Ceres, edge to edge", 940000 },
  { "Makemake, edge to edge", 1430000 },
  { "Pluto, edge to edge", 2377000 },
  { "The Moon, edge to edge", 3474000 },
  { "Mercury, edge to edge", 4879000 },
  { "Mars, edge to edge", 6779000 },
  { "O3b satellites", 8062000 },
  { "Earth, edge to edge", 12742000 },
  { "GPS satellites", 20200000 },
  { "Geostationary orbit", 35786000 },
  { "Once around the Earth", 40075000 },
  { "Neptune, edge to edge", 49244000 },
  { "Twice around the Earth", 80150000 },
  { "Saturn, edge to edge", 116460000 },
  { "Jupiter, edge to edge", 139820000 },
  { "Saturn's rings, edge to edge", 273000000 },
  { "The Moon", 384400000 },
  { "To the Moon and back", 768800000 },
  { "The Sun, edge to edge", 1392700000 },
  { "The Moon's orbit, all the way round", 2415000000 },
  { "Around the Sun", 4375000000 },
}

for i, row in ipairs(Landmarks) do
  Landmarks[i] = { name = row[1], m = row[2], wow = row[3] == "wow" }
end

ns.Landmarks = Landmarks
return Landmarks
