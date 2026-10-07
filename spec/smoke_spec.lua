-- Loads the whole addon on a mocked client and plays it end to end.
local Mock = require("spec.wow_mock")

describe("addon on a mocked client", function()
  local ns

  setup(function()
    ns = Mock.load("Jumpers.toc")
    Mock.fire("ADDON_LOADED", "Jumpers")
    Mock.fire("PLAYER_LOGIN")
  end)

  it("starts with defaults", function()
    assert.equal(100, JumpersDB.settings.size)
    assert.equal(0, JumpersDB.settings.volume)
    assert.equal("m", ns.Settings.Units())
  end)

  it("ignores standing jumps", function()
    Mock.advance(5)
    Mock.jump()
    assert.equal(0, ns.char.jumps)
  end)

  it("counts a running streak, ends it and records a NEW BEST", function()
    local fired = {}
    ns.On("STREAK_END", function(n, isNewBest) fired.n, fired.best = n, isNewBest end)
    Mock.moving = true
    Mock.fire("PLAYER_STARTED_MOVING")
    for _ = 1, 30 do Mock.jump() end
    assert.equal(30, ns.streak.n)
    assert.is_true(ns.CounterUI.counter.root:IsShown())
    Mock.moving = false
    Mock.fire("PLAYER_STOPPED_MOVING")
    Mock.advance(3.5)
    assert.equal(30, fired.n)
    assert.is_true(fired.best)
    assert.equal(30, ns.char.jumps)
    assert.equal(30, ns.char.best)
    assert.equal(1, ns.char.streaks)
    Mock.advance(3)
    assert.is_false(ns.CounterUI.counter.root:IsShown())
  end)

  it("counts turning in place inside a streak", function()
    Mock.moving = true
    Mock.fire("PLAYER_STARTED_MOVING")
    Mock.jump()
    Mock.moving = false
    Mock.fire("PLAYER_STOPPED_MOVING")
    Mock.advance(0.5)
    Mock.jump()                       -- moved since the last jump (stopped after it)
    Mock.jump()                       -- no movement: ignored
    assert.equal(2, ns.streak.n)
    Mock.facing = 1.0
    Mock.advance(0.2)
    Mock.jump()                       -- turned
    assert.equal(3, ns.streak.n)
    Mock.facing = 0
    Mock.advance(4)
  end)

  it("shows a milestone caption", function()
    local seen
    ns.On("MILESTONE", function(i) seen = i end)
    Mock.moving = true
    Mock.fire("PLAYER_STARTED_MOVING")
    for _ = 1, 35 do Mock.jump() end   -- 33 -> 68 jumps = 102 m: past the Statue of Liberty (93 m)
    assert.is_not_nil(seen)
    Mock.moving = false
    Mock.fire("PLAYER_STOPPED_MOVING")
    Mock.advance(5)
  end)

  it("plays every tier and ornament on the demo, up to the rainbow", function()
    SlashCmdList.JUMPERS("demo 1010")
    Mock.advance(0.22 * 1010 + 0.1)
    local c = ns.CounterUI.counter
    assert.equal(1010, c.n)
    assert.is_true(c.look.rainbow)
    assert.equal(6, c.look.ornaments)
    Mock.advance(4)
  end)

  it("opens the window and every tab", function()
    SlashCmdList.JUMPERS("")
    ns.Window.Select("stats")
    Mock.advance(0.1)
    ns.Window.Select("board")
    ns.Window.Select("settings")
    Mock.advance(0.5)
    ns.Settings.Set("size", 150)
    ns.Settings.Set("units", "ft")
    ns.Settings.Set("unlocked", true)
    Mock.advance(0.5)
    ns.Settings.Set("unlocked", false)
    ns.Settings.Set("volume", 50)
    Mock.moving = true
    Mock.fire("PLAYER_STARTED_MOVING")
    for _ = 1, 3 do Mock.jump() end
    assert.is_true((Mock.sounds or 0) > 0)
    ns.Window.Select("stats")
    ns.StatsTab.Refresh()
    Mock.advance(4)
    ns.Window.Toggle()
  end)

  it("resets progress", function()
    assert.is_true(ns.char.jumps > 0)
    ns.ResetProgress()
    assert.equal(0, ns.char.jumps); assert.equal(0, ns.account.jumps); assert.equal(0, ns.char.best)
    assert.equal(0, JumpersCharDB.stats.jumps)
  end)
end)
