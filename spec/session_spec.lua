local load = require("spec.load")
local Session = load("Session")
local Stats = load("Stats")

describe("Session", function()
  it("counts jumping time, capped per jump", function()
    local s = Session.new(100)
    assert.equal(1.5, Session.jump(s, 110))     -- first jump
    assert.equal(1, Session.jump(s, 111))       -- a quick chain counts in full
    assert.equal(1.5, Session.jump(s, 200))     -- after a pause, only one jump's worth
    assert.equal(3, s.jumps); assert.equal(4, s.active)
    assert.equal(4 / 100, Session.share(s.active, Session.elapsed(s, 200)))
    assert.equal(0, Session.share(5, 0))
  end)

  it("reports the session and the recent rate", function()
    local s = Session.new(0)
    for i = 1, 60 do Session.jump(s, i) end     -- 60 jumps in the first minute
    assert.equal(60, Session.rate(s, 60))
    assert.equal(60, Session.recentRate(s, 60))
    assert.equal(6, Session.rate(s, 600))
    assert.equal(0, Session.recentRate(s, 600)) -- nothing in the last five minutes
    Session.jump(s, 601)
    assert.equal(0.2, Session.recentRate(s, 601))
  end)
end)

describe("Stats time", function()
  it("keeps online and jumping time and the best session", function()
    local s = Stats.ensure({ jumps = 5 })
    assert.same({ 0, 0, 0 }, { s.online, s.active, s.bestSession })
    Stats.addTime(s, 60, 2)
    Stats.noteSession(s, 40); Stats.noteSession(s, 10)
    assert.same({ 60, 2, 40 }, { s.online, s.active, s.bestSession })
  end)
end)
