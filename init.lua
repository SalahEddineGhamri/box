-- mod-version:3
-- Box Plugin for Pragtical
-- Implements a command/input box (minibuffer/quickfix style)

local core = require "core"
local common = require "core.common"
local command = require "core.command"
local command_view = require "plugins.box.commandview_patch"


local Box = {}
Box.active = false
Box.prompt = ""
Box.items = {}
Box.on_select = nil

function Box.open(prompt, items, on_select)
  Box.active = true
  Box.prompt = prompt or "Box"
  Box.items = items or {}
  Box.on_select = on_select

  command_view:enter(Box.prompt, {
    submit = function(text, item)
      if Box.on_select then
        Box.on_select(item and item.text or text)
      end
      Box.close()
    end,
    suggest = function(text)
      return Box.fuzzy_filter(Box.items, text)
    end,
    cancel = function()
      Box.close()
    end,
  })
end

function Box.close()
  Box.active = false
  Box.prompt = ""
  Box.items = {}
  Box.on_select = nil
end

function Box.fuzzy_filter(items, query)
  if not query or query == "" then return items end
  local filtered = {}
  local q = query:lower()
  for _, item in ipairs(items) do
    local txt = type(item) == "table" and item.text or item
    if txt:lower():find(q, 1, true) then
      table.insert(filtered, { text = txt })
    end
  end
  return filtered
end

command.add(nil, {
  ["box:select-fruit"] = function()
    Box.api.open("Select Fruit", {"Apple","Banana","Cherry"}, function(choice)
      if choice then
        core.log("You picked: %s", choice)
      else
        core.log("No fruit selected")
      end
    end)
  end,
})


Box.api = {
  open = Box.open,
  close = Box.close
}

return Box
