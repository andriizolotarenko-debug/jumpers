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

  it("shares streaks and builds the leaderboard", function()
    local Wire = ns.Wire
    Mock.advance(10)                                -- channel joined, heartbeat and sync sent
    assert.is_true(ns.Comm.status.channel)
    local own = ns.Board.top(ns.board, ns.Today(), 1)
    assert.equal("Tester-TestRealm", own[1].p)      -- our x30 from the first streak
    local found = false
    for _, m in ipairs(Mock.sent) do if m:match("^R|1|HUNTER|30|") then found = true end end
    assert.is_true(found)

    local now = GetServerTime()
    local live = { c = "MAGE", n = 64, e = now - 2, d = ns.Today(), u = 60, g = 0.7 }
    Mock.fire("CHAT_MSG_ADDON", "JMPR", Wire.record(live), "CHANNEL", "Ann-TestRealm")
    local relayed = { p = "Bob-TestRealm", c = "ROGUE", n = 99, e = now - 4000, d = ns.Today(), u = 90, g = 0.7 }
    Mock.fire("CHAT_MSG_ADDON", "JMPR", Wire.relay(relayed), "GUILD", "Cid-TestRealm")
    assert.equal(2, #ns.Board.top(ns.board, ns.Today(), 1))   -- Bob still unconfirmed
    Mock.fire("CHAT_MSG_ADDON", "JMPR", Wire.relay(relayed), "CHANNEL", "Dee-TestRealm")
    local top = ns.Board.top(ns.board, ns.Today(), 1)
    assert.same({ "Bob-TestRealm", "Ann-TestRealm", "Tester-TestRealm" }, { top[1].p, top[2].p, top[3].p })
    -- a fake: too fast to be real
    local fake = { c = "MAGE", n = 500, e = now, d = ns.Today(), u = 10, g = 0.1 }
    Mock.fire("CHAT_MSG_ADDON", "JMPR", Wire.record(fake), "CHANNEL", "Eve-TestRealm")
    assert.equal(3, #ns.Board.top(ns.board, ns.Today(), 1))

    local before = #Mock.sent
    Mock.fire("CHAT_MSG_ADDON", "JMPR", Wire.query(), "CHANNEL", "Fay-TestRealm")
    Mock.advance(40)
    local relays = 0
    for i = before + 1, #Mock.sent do if Mock.sent[i]:match("^S|") then relays = relays + 1 end end
    assert.is_true(relays > 0)
    for i = before + 1, #Mock.sent do assert.is_nil(Mock.sent[i]:match("^S|1|Tester")) end  -- never our own

    -- self-test: the echo of our own "T" message is checked and never stored
    local printed = {}
    local print0 = ns.Print
    ns.Print = function(m) printed[#printed + 1] = m end
    before = #Mock.sent
    SlashCmdList.JUMPERS("selftest")
    Mock.advance(3)
    local echo
    for i = before + 1, #Mock.sent do if Mock.sent[i]:match("^T|1|") then echo = Mock.sent[i] end end
    assert.is_not_nil(echo)
    Mock.fire("CHAT_MSG_ADDON", "JMPR", echo, "CHANNEL", "Tester-TestRealm")
    Mock.fire("CHAT_MSG_ADDON", "JMPR", echo, "GUILD", "Tester")
    Mock.fire("CHAT_MSG_ADDON", "JMPR", echo, "CHANNEL", "Gus-TestRealm")      -- someone else's test
    Mock.advance(30)
    ns.Print = print0
    local text = table.concat(printed, "\n")
    assert.truthy(text:find("channel echo after", 1, true)); assert.truthy(text:find("guild echo after", 1, true))
    assert.truthy(text:find("decoded and verified", 1, true)); assert.falsy(text:find("no guild echo", 1, true))
    assert.equal(3, #ns.Board.top(ns.board, ns.Today(), 1))

    -- past 50 players our place shows as "50+"
    for i = 1, 55 do
      ns.Board.addFirstHand(ns.board, { p = "P" .. i .. "-TestRealm", c = "MAGE", n = 200 + i, e = now - 10,
        d = ns.Today(), u = 200, g = 0.6 })
    end
    ns.Window.Show("board")
    local online = ns.Comm.Online()
    assert.is_true(online["Ann-TestRealm"]); assert.is_true(online["Tester-TestRealm"])
    ns.BoardTab.Refresh()
    local pinned = false
    for _, f in ipairs(Mock.frames) do if f._text == "50+" then pinned = true end end
    assert.is_true(pinned)
    SlashCmdList.JUMPERS("demoboard")
    ns.BoardTab.Refresh()
    SlashCmdList.JUMPERS("demoboard")
    ns.Window.Toggle()
  end)

  it("resets progress", function()
    assert.is_true(ns.char.jumps > 0)
    ns.ResetProgress()
    assert.equal(0, ns.char.jumps); assert.equal(0, ns.account.jumps); assert.equal(0, ns.char.best)
    assert.equal(0, JumpersCharDB.stats.jumps)
  end)
end)
