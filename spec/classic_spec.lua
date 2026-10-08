-- A Classic client: custom channels can't carry addon messages there, so records travel
-- through the guild, the group and by whisper to players we met.
local Mock = require("spec.wow_mock")

describe("addon on a mocked Classic client", function()
  local ns, Wire

  setup(function()
    ns = Mock.load("Jumpers.toc", 5)
    Wire = ns.Wire
    Mock.fire("ADDON_LOADED", "Jumpers")
    Mock.fire("PLAYER_LOGIN")
    Mock.group = "PARTY"
    Mock.advance(12)
  end)

  local function routes(from, pattern, target)
    local out = {}
    for i = from + 1, #Mock.routes do
      local r = Mock.routes[i]
      if r.msg:match(pattern) and (not target or r.target == target) then out[#out + 1] = r end
    end
    return out
  end

  it("never joins the channel and talks to the group instead", function()
    assert.equal("off", ns.Comm.status.channelState)
    assert.is_true(ns.Comm.Fallback())
    assert.is_nil(Mock.joined)
    assert.equal(0, #routes(0, ".", "CHANNEL"))
    assert.is_true(#routes(0, "^H|", "PARTY") > 0)
  end)

  it("remembers group mates and answers whispered sync requests by whisper", function()
    Mock.fire("CHAT_MSG_ADDON", "JMPR", Wire.heartbeat("MAGE"), "PARTY", "Ann")
    assert.is_not_nil(ns.board.peers["Ann-TestRealm"])
    local now = GetServerTime()
    local other = { p = "Cid-TestRealm", c = "ROGUE", n = 40, e = now - 100, d = ns.Today(), u = 35, g = 0.7 }
    ns.Board.addFirstHand(ns.board, other)
    local before = #Mock.routes
    Mock.fire("CHAT_MSG_ADDON", "JMPR", Wire.query(), "WHISPER", "Bob")
    Mock.advance(10)
    local answer = routes(before, ".", "WHISPER")
    assert.equal("Bob-TestRealm", answer[1].to)
    assert.truthy(answer[1].msg:match("^H|"))
    assert.truthy(answer[2].msg:match("^S|1|Cid%-TestRealm|"))
    assert.truthy(answer[#answer].msg:match("^Q|"))                     -- and asks back
    -- a second request within the cooldown is not answered again
    before = #Mock.routes
    Mock.fire("CHAT_MSG_ADDON", "JMPR", Wire.query(), "WHISPER", "Bob")
    Mock.advance(5)
    assert.equal(0, #routes(before, ".", "WHISPER"))
  end)

  it("whispers live records to peers only a whisper reaches", function()
    local before = #Mock.routes
    local t = GetTime()
    ns.Comm.OwnStreak({ n = 30, startedAt = t - 25, endedAt = t, minGap = 0.6 }, true)
    Mock.advance(5)
    local live = routes(before, "^R|1|HUNTER|30|")
    local targets = {}
    for _, r in ipairs(live) do targets[r.target .. (r.to or "")] = true end
    assert.is_true(targets.GUILD); assert.is_true(targets.PARTY); assert.is_true(targets["WHISPERBob-TestRealm"])
    assert.is_nil(targets["WHISPERAnn-TestRealm"])                     -- the group already reaches Ann
  end)

  it("asks peers it has not heard from lately, and hides 'player not found'", function()
    Mock.group = nil
    local before = #Mock.routes
    Mock.advance(960)                                                  -- Ann and Bob go quiet
    local asks = routes(before, "^Q|", "WHISPER")
    local to = {}
    for _, r in ipairs(asks) do to[r.to] = true end
    assert.is_true(to["Ann-TestRealm"])
    Mock.fire("CHAT_MSG_ADDON", "JMPR", Wire.query(), "WHISPER", "Dan")    -- we whisper Dan back right away
    Mock.advance(3)
    local hide = Mock.filters.CHAT_MSG_SYSTEM
    assert.is_true(hide(nil, "CHAT_MSG_SYSTEM", "No player named 'Dan-TestRealm' is currently playing."))
    assert.is_false(hide(nil, "CHAT_MSG_SYSTEM", "No player named 'Zed' is currently playing."))
  end)

  it("self-tests guild, group and whisper but not the channel", function()
    Mock.group = "RAID"
    local printed = {}
    local print0 = ns.Print
    ns.Print = function(m) printed[#printed + 1] = m end
    SlashCmdList.JUMPERS("selftest")
    Mock.advance(40)
    ns.Print = print0
    local text = table.concat(printed, "\n")
    assert.truthy(text:find("not available on Classic", 1, true))
    for _, route in ipairs({ "guild", "raid", "whisper" }) do assert.truthy(text:find(route .. " echo after", 1, true)) end
    assert.falsy(text:find("no ", 1, true))
    ns.Window.Show("board")
    ns.BoardTab.Refresh()
  end)
end)
