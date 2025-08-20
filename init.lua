-- mod-version:3
local core = require "core"
local style = require "core.style"
local CommandView = require "core.commandview"

---@class core.box : core.commandview
local Box = CommandView:extend()

function Box:__tostring() return "Box" end

function Box:new()
  Box.super.new(self)
  self.size.y = 0
end

function Box:enter(label, ...)
  self.size.y = 60
  return Box.super.enter(self, "[BOX] " .. label, ...)
end

function Box:exit(submitted, inexplicit)
  Box.super.exit(self, submitted, inexplicit)
  self.size.y = 0
end

function Box:get_name()
  return "Box"
end

function Box:get_min_height()
  return 60
end

function Box:update()
  CommandView.update(self)
  if self.size.y > 0 and self.size.y < 60 then
    self.size.y = 60
  end
end

function Box:draw()
  if self.size.y <= 0 then
    return
  end

  local renderer = require "renderer"
  renderer.draw_rect(self.position.x, self.position.y, self.size.x, self.size.y, style.background2)

  CommandView.draw(self)
end

-- Initialize the box view
core.add_thread(function()
  while not core.root_view do
     coroutine.yield()
  end

  for _ = 1, 10 do coroutine.yield() end

  local box = Box()
  core.box_view = box

  local active_node = core.root_view:get_active_node()
  local new_node = active_node:split("down", core.box_view, {y = true})

  if new_node and new_node.b then
    new_node:set_split(0.95)
  end

end)

local command = require "core.command"

local function show_box_command()
  if not core.box_view then
    return
  end

  local options = {
    submit = function(text, suggestion)
      core.log("User submitted: " .. text)
    end,
    suggest = function(text)
      return { "example:one", "example:two", "another:example" }
    end,
    show_suggestions = true,
  }

  core.box_view:enter("box >", options)
  core.set_active_view(core.box_view)
end

command.add(nil, {
  ["box:open"] = show_box_command,
})

return Box


