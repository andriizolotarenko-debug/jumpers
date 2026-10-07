-- ADAPTER: turns jump key presses into counted jumps (R1.3, R1.3a, R1.4).
-- Every game value is read defensively: a missing or hidden value means "don't count".
local _, ns = ...

local Detector = {}
ns.Detector = Detector

local TURN = 0.05        -- radians of facing change that count as movement
local CONFIRM = 0.35     -- the character must leave the ground within this time
local CONFIRM_STEP = 0.05

local moving = false
local lastMoveAt = -math.huge
local facingAtJump = nil
local turned = false
local pending = false

local issecret = issecretvalue or function() return false end

-- Calls a game function; nil when it is missing, errors or returns a hidden value.
local function read(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok or v == nil or issecret(v) then return nil end
  return v
end

local function facing()
  local f = read(GetPlayerFacing)
  if type(f) ~= "number" then return nil end
  return f
end

local function angleDiff(a, b)
  local d = math.abs(a - b) % (2 * math.pi)
  if d > math.pi then d = 2 * math.pi - d end
  return d
end

local function airborne()
  return read(IsFalling) == true
end

local function blocked()
  if airborne() then return true end                 -- already in the air: the press does nothing
  if read(IsSwimming) == true then return true end    -- the key means ascend
  if read(IsFlying) == true then return true end
  if read(UnitOnTaxi, "player") == true then return true end
  if read(HasFullControl) == false then return true end
  return false
end

local function movedSinceLastJump(now)
  local movingNow = moving or read(IsPlayerMoving) == true
  if movingNow then return true end
  local s = ns.streak
  if s:active() then
    if lastMoveAt > s.last or turned then return true end
    local f = facing()
    return f ~= nil and facingAtJump ~= nil and angleDiff(f, facingAtJump) > TURN
  end
  -- first jump of a streak: moved within the last window
  return now - lastMoveAt <= ns.Streak.WINDOW
end

local function count(t)
  turned = false
  facingAtJump = facing()
  ns.CountedJump(t)
end

local function onPress()
  if pending then return end
  local now = GetTime()
  if blocked() or not movedSinceLastJump(now) then return end
  -- takeoff confirm: roots and blocked jumps never leave the ground
  pending = true
  local waited = 0
  local confirm
  confirm = C_Timer.NewTicker(CONFIRM_STEP, function()
    waited = waited + CONFIRM_STEP
    if airborne() then
      confirm:Cancel()
      pending = false
      count(now)
    elseif waited >= CONFIRM then
      confirm:Cancel()
      pending = false
    end
  end)
end

-- Called from the streak loop (~20 Hz, only during a streak): catches turning in place.
function Detector.Poll()
  if turned or facingAtJump == nil then return end
  local f = facing()
  if f and angleDiff(f, facingAtJump) > TURN then turned = true end
end

function Detector.Init()
  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_STARTED_MOVING")
  events:RegisterEvent("PLAYER_STOPPED_MOVING")
  events:SetScript("OnEvent", function(_, event)
    moving = event == "PLAYER_STARTED_MOVING"
    lastMoveAt = GetTime()
  end)
  if type(JumpOrAscendStart) == "function" then
    hooksecurefunc("JumpOrAscendStart", onPress)
  else
    ns.Print("can't see jumps on this client. Please report it.")
  end
end
