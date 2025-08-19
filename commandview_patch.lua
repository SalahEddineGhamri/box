local core   = require "core"
local style  = require "core.style"
local common = require "core.common"
local CommandView = require "core.commandview"
local config = require "core.config"

-- force input at top
local orig_update = CommandView.update
function CommandView:update()
  orig_update(self)
  self.position.y = 0
  self.size.y = self:get_line_height() + style.padding.y * 2
end

-- override draw
local orig_draw = CommandView.draw
function CommandView:draw()
  -- draw input at top
  CommandView.super.draw(self)

  if not self.state.show_suggestions or #self.suggestions == 0 then return end

  local lh = self:get_suggestion_line_height()
  local dh = style.divider_size
  local rx, ry = self.position.x, self.position.y + self.size.y + dh
  local rw, rh = self.size.x, math.ceil(self.suggestions_height)

  -- background + divider
  renderer.draw_rect(rx, ry, rw, rh, style.background3)
  renderer.draw_rect(rx, ry, rw, dh, style.divider)

  -- scrolling logic from original
  local cur = self.suggestion_idx
  local offset = math.max(cur - config.max_visible_commands, 0)
  local first = 1 + offset
  local last = math.min(offset + config.max_visible_commands, #self.suggestions)

  if cur < self.suggestions_first or cur > self.suggestions_last
     or self.suggestions_last - self.suggestions_first < last - first then
    self.suggestions_first = first
    self.suggestions_last = last
    self.suggestions_offset = offset
  else
    offset = self.suggestions_offset
    first = self.suggestions_first
    last = math.min(self.suggestions_last, #self.suggestions)
  end

  core.push_clip_rect(rx, ry, rw, rh)
  local font = self:get_font()
  for i = first, last do
    local item = self.suggestions[i]
    local y = ry + (i - offset - 1) * lh
    local color = (i == cur) and style.accent or style.text
    if i == cur then
      renderer.draw_rect(rx, y, rw, lh, style.line_highlight)
    end
    local w = self.size.x - style.padding.x
    common.draw_text(font, color, item.text, nil, style.padding.x, y, 0, lh)
    if item.info then
      common.draw_text(font, style.dim, item.info, "right", style.padding.x, y, w, lh)
    end
  end
  core.pop_clip_rect()
end

-- keep mouse hit test valid
function CommandView:is_mouse_on_suggestions()
  if self.state.show_suggestions and #self.suggestions > 0 then
    local mx, my = self.mouse_position.x, self.mouse_position.y
    local dh = style.divider_size
    local sh = math.ceil(self.suggestions_height)
    local x, y, w, h = self.position.x, self.position.y + self.size.y + dh, self.size.x, sh
    return mx >= x and mx <= x+w and my >= y and my >= y and my <= y+h
  end
  return false
end

return CommandView
