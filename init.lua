-- =====================================================================
--  Snippet Menu for Hammerspoon
--
--  A menu bar menu of text snippets that YOU write in snippets.txt.
--  Clicking a snippet copies it to the clipboard. That's all.
--
--  This is NOT a clipboard manager: this file never reads, watches,
--  or saves anything you copy. It only ever WRITES your own snippets
--  to the clipboard when you click one.
-- =====================================================================


-- ---------------------------------------------------------------------
--  SETTINGS - safe to change
-- ---------------------------------------------------------------------

-- Keyboard shortcut that opens the menu at your mouse pointer.
-- Modifier names: "ctrl" (Control), "alt" (Option), "cmd" (Command), "shift"
local HOTKEY_MODIFIERS = { "ctrl", "alt" }
local HOTKEY_KEY       = "s"

-- What appears in the menu bar.
local MENUBAR_TITLE    = "✂︎"

-- Where your snippets live.
local SNIPPETS_FILE    = os.getenv("HOME") .. "/.hammerspoon/snippets.txt"

-- How long (in seconds) the "Copied: ..." message stays on screen.
local COPIED_MESSAGE_SECONDS = 1.5


-- ---------------------------------------------------------------------
--  Messages to you
-- ---------------------------------------------------------------------

-- Short on-screen message. Works without any macOS permissions.
local function showMessage(text, seconds)
  hs.alert.closeAll()
  hs.alert.show(text, seconds or COPIED_MESSAGE_SECONDS)
end

-- Problems are shown twice: as an on-screen message (always visible)
-- and as a macOS notification (stays in Notification Center).
local function showError(text)
  hs.alert.show("Snippets problem:\n" .. text, 6)
  hs.notify.new({
    title           = "Snippet Menu: problem",
    informativeText = text,
    withdrawAfter   = 0,
  }):send()
end


-- ---------------------------------------------------------------------
--  Reading snippets.txt
--
--  Format (see snippets.txt for a full example):
--    # Category
--    ## Subcategory            (optional)
--    ### Snippet title
--    The text that gets copied. As many lines as you like.
-- ---------------------------------------------------------------------

local function trimBlankLines(lines)
  while #lines > 0 and lines[1]:match("^%s*$") do table.remove(lines, 1) end
  while #lines > 0 and lines[#lines]:match("^%s*$") do table.remove(lines) end
  return lines
end

-- Returns a list of categories, or nil plus an error message.
local function readSnippets(path)
  local file = io.open(path, "r")
  if not file then
    return nil, "Couldn't find your snippets file.\nIt should be at: " .. path
  end
  local content = file:read("a")
  file:close()

  if not content or content:match("^%s*$") then
    return nil, "Your snippets file is empty:\n" .. path
  end

  local categories = {}
  local category, subcategory, snippet
  local problems = {}
  local count = 0

  local function finishSnippet()
    if snippet then
      snippet.text = table.concat(trimBlankLines(snippet.lines), "\n")
      snippet.lines = nil
      if snippet.text == "" then
        table.insert(problems, "\"" .. snippet.title .. "\" has no text, so it was left out.")
      else
        table.insert(snippet.parent, snippet)
        count = count + 1
      end
      snippet = nil
    end
  end

  local lineNumber = 0
  -- Normalize Windows/old-Mac line endings so every line splits cleanly.
  content = content:gsub("\r\n", "\n"):gsub("\r", "\n")
  for line in (content .. "\n"):gmatch("(.-)\n") do
    lineNumber = lineNumber + 1
    local hashes, heading = line:match("^(#+)%s+(.-)%s*$")

    if hashes == "#" then
      finishSnippet()
      category = { title = heading, subcategories = {}, snippets = {} }
      table.insert(categories, category)
      subcategory = nil

    elseif hashes == "##" then
      finishSnippet()
      if not category then
        table.insert(problems, "Line " .. lineNumber .. ": subcategory \"" .. heading ..
          "\" needs a # Category above it.")
      else
        subcategory = { title = heading, snippets = {} }
        table.insert(category.subcategories, subcategory)
      end

    elseif hashes == "###" then
      finishSnippet()
      local parent = (subcategory and subcategory.snippets) or (category and category.snippets)
      if not parent then
        table.insert(problems, "Line " .. lineNumber .. ": snippet \"" .. heading ..
          "\" needs a # Category above it.")
      else
        snippet = { title = heading, lines = {}, parent = parent }
      end

    elseif snippet then
      table.insert(snippet.lines, line)
    end
    -- Anything else (text outside a snippet) is ignored, so you can
    -- leave yourself notes at the top of the file.
  end
  finishSnippet()

  if count == 0 then
    return nil, "No snippets found in " .. path ..
      "\nEach snippet needs a line starting with ### followed by its text." ..
      (#problems > 0 and ("\n\n" .. table.concat(problems, "\n")) or "")
  end

  return categories, (#problems > 0 and table.concat(problems, "\n") or nil)
end


-- ---------------------------------------------------------------------
--  Building the menu
-- ---------------------------------------------------------------------

local function copySnippet(snippet)
  hs.pasteboard.setContents(snippet.text)
  showMessage("Copied: " .. snippet.title)
end

-- Hover over a snippet to see the start of its text.
local function preview(text)
  if #text > 300 then return text:sub(1, 300) .. "…" end
  return text
end

local function snippetItems(snippets)
  local items = {}
  for _, snippet in ipairs(snippets) do
    table.insert(items, {
      title   = snippet.title,
      tooltip = preview(snippet.text),
      fn      = function() copySnippet(snippet) end,
    })
  end
  return items
end

local function buildMenu(categories)
  local menu = {}

  if not categories then
    table.insert(menu, { title = "⚠️ Snippets couldn't be loaded", disabled = true })
    table.insert(menu, { title = "Details: see the notification", disabled = true })
  else
    for _, category in ipairs(categories) do
      local items = {}
      for _, sub in ipairs(category.subcategories) do
        if #sub.snippets > 0 then
          table.insert(items, { title = sub.title, menu = snippetItems(sub.snippets) })
        end
      end
      if #category.subcategories > 0 and #category.snippets > 0 then
        table.insert(items, { title = "-" })  -- divider line
      end
      for _, item in ipairs(snippetItems(category.snippets)) do
        table.insert(items, item)
      end
      if #items > 0 then
        table.insert(menu, { title = category.title, menu = items })
      end
    end
  end

  table.insert(menu, { title = "-" })
  table.insert(menu, {
    title = "Edit snippets…",
    fn = function() hs.execute('open -e "' .. SNIPPETS_FILE .. '"') end,
  })
  table.insert(menu, { title = "Reload snippets", fn = function() hs.reload() end })
  return menu
end


-- ---------------------------------------------------------------------
--  Start up
--  (Stored in globals so macOS doesn't quietly throw them away.)
-- ---------------------------------------------------------------------

local categories, message = readSnippets(SNIPPETS_FILE)

snippetMenubar = hs.menubar.new()
snippetMenubar:setTitle(MENUBAR_TITLE)
snippetMenubar:setTooltip("Snippets")
snippetMenubar:setMenu(buildMenu(categories))

snippetHotkey = hs.hotkey.bind(HOTKEY_MODIFIERS, HOTKEY_KEY, function()
  snippetMenubar:popupMenu(hs.mouse.absolutePosition())
end)

if message then
  showError(message)   -- file missing/empty, or some snippets had mistakes
else
  showMessage("Snippets loaded", 1)
end
