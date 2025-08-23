-- mod-version:3
-- Author: S.Ghamri----------------------------------------------------------------

-- TODO: max_selection shifts drawing
-- TODO: wrapping ?! low prio

-- TODO: create API to:
--       - set the label
--       - get the suggestions

-- TODO: mouse selection low prio

-- DONE: drawing should return to 1
-- DONE: make label updatable
-- DONE: add stats on how many entry
-- DONE: enhance the look and the feeling. move suggestions to the right
-- DONE: fuzzy search is not working 
-----------------------------------------------------------------------------------

local core = require "core"
local style = require "core.style"
local CommandView = require "core.commandview"
local common = require "core.common"

local max_suggestions = 10

---@class core.box : core.commandview
local Box = CommandView:extend()

function Box:__tostring() return "Box" end

function Box:new()
  Box.super.new(self)
  self.suggestions_offset = 1
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

function Box:get_suggestion_line_height()
  return self:get_font():get_height()
end

function Box:update()
  Box.super.update(self)

  -- TODO: do we need default_state, we get it from CommandView ??
  if core.active_view ~= self then
    self:exit(false, true)
  end

  -- update suggestions if text has changed
  if self.last_change_id ~= self.doc:get_change_id() then
    self:update_suggestions()
    if self.state.typeahead and self.suggestions[self.suggestion_idx] then
      local current_text = self:get_text()
      local suggested_text = self.suggestions[self.suggestion_idx].text or ""
      if #self.last_text < #current_text and
         string.find(suggested_text, current_text, 1, true) == 1 then
        self:set_text(suggested_text)
        self.doc:set_selection(1, #current_text + 1, 1, math.huge)
      end
      self.last_text = current_text
    end
    self.last_change_id = self.doc:get_change_id()
  end

  -- update gutter text color brightness
  self:move_towards("gutter_text_brightness", 0, 0.1, "box")

  -- update gutter width
  local dest = self:get_font():get_width(self.label) + style.padding.x
  if self.size.y <= 0 then
    self.gutter_width = dest
  else
    self:move_towards("gutter_width", dest, nil, "box")
  end

  -- update suggestions box height
  --local lh = self:get_suggestion_line_height()
  --local dest = self.state.show_suggestions and math.min(#self.suggestions, max_suggestions) * lh or 0
  --self:move_towards("suggestions_height", dest, nil, "box")

  -- update suggestion cursor offset
  local dest = (self.suggestion_idx - self.suggestions_offset + 1)  * self:get_suggestion_line_height()
  self:move_towards("selection_offset", dest, nil, "box")

  -- update size based on whether this is the active_view
  local target_y = 0
  if core.active_view == self then
    local status_bar_height = style.font:get_height() + style.padding.y * 2
    target_y = max_suggestions * (self:get_suggestion_line_height() + style.padding.y) + style.divider_size + self:get_line_height() 
  end

  self:move_towards(self.size, "y", target_y, nil, "box")
end

-- m: move_suggestion_idx
function Box:move_suggestion_idx(dir)

  local s = self.suggestions or {}
  local n, count 

  dir = - dir 

  -- down +1
  self.suggestion_idx = self.suggestion_idx + dir

  local function get_suggestions_offset()
    local count = #self.suggestions
    if count == 0 then return 1 end
    local max_visible = math.min(max_suggestions, count)
    if dir > 0 then
      -- moving down
      if self.suggestion_idx >= self.suggestions_offset + max_visible then
        return self.suggestion_idx - max_visible + 1
      else
        return self.suggestions_offset
      end
    else
      -- moving up
      if self.suggestion_idx < self.suggestions_offset then
        return self.suggestion_idx
      else
        return self.suggestions_offset
      end
    end
  end

  -- between 1 and #s
  self.suggestion_idx = math.max(1, math.min(self.suggestion_idx, #s))

  local current_text = self:get_text()
  local current_suggestion = s[self.suggestion_idx] and s[self.suggestion_idx].text or ""

  if n == #s then -- reach list end
    self.save_suggestion = current_text
  end

  -- it gets always the last element
  self.suggestions_offset = get_suggestions_offset()

  -- update text in input area
  local new_text = s[self.suggestion_idx].text or ""
  self:set_text(new_text)
  self.doc:set_selection(1, #new_text + 1, 1, math.huge)

  if self.state.show_suggestions then
    self.state.suggest(new_text) -- fuzzy match this or else
  end

  self.last_change_id = self.doc:get_change_id()

end

-- m: line gutter
function Box:draw_line_gutter(_, x, y)
  local yoffset = self:get_line_text_y_offset()
  local pos = self.position
  self.gutter_text_brightness = 70
  local color = common.lerp(style.text, style.accent, self.gutter_text_brightness / 100)
  core.push_clip_rect(pos.x, pos.y, self:get_gutter_width(), self.size.y)
  x = x + style.padding.x
  self.label = self.label_fn()
  -- self.label = self.label
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
  local ry = self.position.y + self:get_line_height() + dh -- y + prompt line + divider
  local rw = self.size.x
  local h = max_suggestions * lh
  local x_offset = style.padding.x

  core.push_clip_rect(x, ry, rw, h)
  
  if #self.suggestions > 0 then
      renderer.draw_rect(x, ry, rw, h, style.background3) 
      renderer.draw_rect(x, ry, rw, dh, style.divider) 
      local sy = ry + (self.suggestion_idx - self.suggestions_offset) * lh
      renderer.draw_rect(x, sy, rw, lh, style.line_highlight) -- selection
  end

  local first = math.max(self.suggestions_offset or 1, 1)
  local last = math.min(first + max_suggestions - 1, #self.suggestions)

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

function Box:enter(label, opt)
    self.suggestions_offset = 1
    if opt and opt.label_fn then
        -- register label function
        self.label_fn = opt.label_fn
    end

    -- label has no effect if label_fn
   Box.super.enter(self, label, opt) 
end
    

local command = require "core.command"

-- m: command
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
    label_fn = function()
        return ""
    end,
  }

  core.box_view:enter("box ", options)
  core.set_active_view(core.box_view)
end

command.add(nil, {
  ["box:open"] = show_box_command,
})

return Box
