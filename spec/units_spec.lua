local load = require("spec.load")
local Units = load("Units")
local Landmarks = load("Landmarks")

describe("Units", function()
  it("formats integers", function()
    assert.equal("0", Units.int(0)); assert.equal("999", Units.int(999))
    assert.equal("1,000", Units.int(1000)); assert.equal("123,456", Units.int(123456))
    assert.equal("4,375,000,000", Units.int(4375000000))
  end)

  it("formats heights in m / ft and km / mi from 100 km", function()
    assert.equal("2,061 m", Units.format(2061, "m"))
    assert.equal("6,762 ft", Units.format(2061, "ft"))
    assert.equal("420 km", Units.format(420000, "m"))
    assert.equal("261 mi", Units.format(420000, "ft"))
  end)

  it("counts floors", function()
    assert.equal(1, Units.floors(2, "m"))      -- 3 m
    assert.equal(0, Units.floors(2, "ft"))     -- 9.8 ft
    assert.equal(1, Units.floors(3, "ft"))     -- 14.8 ft
  end)

  it("defaults by region", function()
    assert.equal("ft", Units.default(1)); assert.equal("m", Units.default(3))
    assert.equal("ft", Units.default(nil, "US")); assert.equal("m", Units.default(nil, nil))
  end)

  it("has 58 rising landmarks", function()
    assert.equal(58, #Landmarks)
    for i = 2, #Landmarks do assert.is_true(Landmarks[i].m > Landmarks[i - 1].m, Landmarks[i].name) end
  end)

  it("finds crossings and progress", function()
    assert.is_nil(Units.crossed(0, 13, Landmarks))       -- 19.5 m
    assert.equal(1, Units.crossed(13, 14, Landmarks))    -- 21 m
    assert.equal(2, Units.crossed(0, 20, Landmarks))     -- 30 m, two at once -> last
    local k, frac, togo = Units.progress(10, Landmarks)  -- 15 m of 20
    assert.equal(0, k); assert.near(0.75, frac, 1e-9); assert.equal(4, togo)
    k, frac, togo = Units.progress(3000000000, Landmarks)
    assert.equal(58, k); assert.equal(1, frac); assert.is_nil(togo)
  end)
end)
