-- mod-version:3
-- Author: S.Ghamri----------------------------------------------------------------

-- TODO: mouse selection needs checking
-- TODO: suggestions navigation is not working correctly
-- TODO: create API to:
--       - set the label
--       - get the suggestions
-- TODO: use it to create soryn file finder

-- TOOO: box can show text only no user prompt, the size changes based on the text
-- TODO: make API clear and can be made usable 

-- DONE: enhance the look and the feeling. move suggestions to the right
-- DONE: fuzzy search is not working 
-----------------------------------------------------------------------------------

local core = require "core"
local style = require "core.style"
local CommandView = require "core.commandview"
local common = require "core.common"

local max_suggestions = 3

---@class core.box : core.commandview
local Box = CommandView:extend()

function Box:__tostring() return "Box" end

function Box:new()
  Box.super.new(self)
end

function Box:set_label(label)
  self.label = label
end

function Box:get_line_screen_position(line, col)
  local x = Box.super.get_line_screen_position(self, 1, col)
  local _, y = self:get_content_offset()
  local lh = self:get_line_height()
  return x, y
end

function Box:draw_background(color)
  local x, y = self.position.x , self.position.y
  local w, h = self.size.x, self.size.y
  --local color = { 255, 0, 0, 255 }
  renderer.draw_rect(x, y, w, h, color)
end

function Box:update()
  Box.super.update(self)

  local target_y = 0
  if core.active_view == self then
    target_y = max_suggestions * self:get_suggestion_line_height()
  end

  self:move_towards(self.size, "y", target_y, nil, "box")
end

function Box:move_suggestion_idx(dir)
  local s = self.suggestions or {}
  local count = math.min(#s, max_suggestions)
  if count == 0 then return end

  local n = self.suggestion_idx - dir -- invert direction
  if self.state.wrap then
    n = (n - 1) % count + 1
  else
    n = math.max(1, math.min(n, count))
  end

  local current_text = self:get_text()
  local current_suggestion = s[self.suggestion_idx] and s[self.suggestion_idx].text or ""

  if n == count then -- reached bottom
    self.save_suggestion = current_text
  end

  self.suggestion_idx = n
  local new_text = s[n].text or self.save_suggestion or ""
  self:set_text(new_text)
  self.doc:set_selection(1, #current_text + 1, 1, math.huge)

  if self.state.show_suggestions then
    self.state.suggest(new_text)
  end

  self.last_change_id = self.doc:get_change_id()
end

function Box:draw_line_gutter(_, x, y)
  local yoffset = self:get_line_text_y_offset()
  local pos = self.position
  self.gutter_text_brightness = 70
  local color = common.lerp(style.text, style.accent, self.gutter_text_brightness / 100)
  core.push_clip_rect(pos.x, pos.y, self:get_gutter_width(), self.size.y)
  x = x + style.padding.x
  renderer.draw_text(self:get_font(), self.label, x, y + yoffset, color)
  core.pop_clip_rect()
  return self:get_line_height()
end

local function draw_suggestions_box(self)
  if not self.state.show_suggestions or #self.suggestions == 0 then
    return
  end
  local lh = self:get_suggestion_line_height()
  local dh = style.divider_size
  local x = self.position.x
  local ry = self.position.y + self:get_line_height()
  local rw = self.size.x
  local h = max_suggestions * lh
  local x_offset = style.padding.x

  core.push_clip_rect(x, ry, rw, h)
  renderer.draw_rect(x, ry, rw, h, style.background3)
  renderer.draw_rect(x, ry, rw, dh, style.divider)

  local first = math.max(self.suggestions_offset or 1, 1)
  local last = math.min(first + max_suggestions - 1, #self.suggestions)

  if self.suggestion_idx and self.suggestion_idx >= first and self.suggestion_idx <= last then
    local sy = ry + (self.suggestion_idx - first) * lh
    renderer.draw_rect(x, sy, rw, lh, style.line_highlight)
  end

  for i = first, last do
    local item = self.suggestions[i]
    local color = (i == self.suggestion_idx) and style.accent or style.text
    local sy = ry + (i - first) * lh
    common.draw_text(self:get_font(), color, item.text, nil, x + x_offset, sy, 0, lh)
    if item.info then
      local w = rw - style.padding.x
      common.draw_text(self:get_font(), style.dim, item.info, "right", x, sy, w, lh)
    end
  end
  core.pop_clip_rect()
end

function Box:draw()
  CommandView.super.draw(self)
  if self.state.show_suggestions then
    core.root_view:defer_draw(draw_suggestions_box, self)
  end
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
  local new_node = active_node:split("down", core.box_view, {y=true})
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
      local all_commands = { "example:one", "example:two", "another:example" }
      local results = {}
      for _, cmd in ipairs(all_commands) do
        if cmd:find(text, 1, true) then
           table.insert(results, cmd)
        end
      end
      return results
      end,
    show_suggestions = true,
  }

  core.box_view:enter("box ", options)
  core.set_active_view(core.box_view)
end

command.add(nil, {
  ["box:open"] = show_box_command,
})

return Box
