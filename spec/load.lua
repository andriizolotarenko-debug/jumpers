-- Loads an addon file the way the game does: with the addon name and a shared namespace.
local ns = {}
return function(name)
  local chunk = assert(loadfile("src/" .. name .. ".lua"))
  return chunk("Jumpers", ns)
end
