local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  error('This plugins requires nvim-telescope/telescope.nvim')
end

local finders       = require'telescope.finders'
local pickers       = require'telescope.pickers'
local actions       = require'telescope.actions'
local action_state  = require'telescope.actions.state'
local Path          = require'plenary.path'
local conf = require('telescope.config').values
local vim = vim

local lookup_keys = {
  value = 1,
  ordinal = 1,
}

local lookup_icon = {
  cell = {icon="", color_name="DevIconCss"},
  func = {icon="", color_name="DevIconEex"},
  class = {icon="", color_name="DevIconC"},
  method = {icon="", color_name="DevIconClojureJS"},
}

local find = (function()
  if Path.path.sep == "\\" then
    return function(t)
      local start, _, filename, lnum, col, text = string.find(t, [[([^:]+):(%d+):(%d+):(.*)]])

      -- Handle Windows drive letter (e.g. "C:") at the beginning (if present)
      if start == 3 then
        filename = string.sub(t, 1, 3) .. filename
      end

      return filename, lnum, col, text
    end
  else
    return function(t)
      local _, _, filename, lnum, col, text = string.find(t, [[([^:]+):(%d+):(%d+):(.*)]])
      return filename, lnum, col, text
    end
  end
end)()

local ltrim=function(s)
  return s:match'^%s*(.*)'
end

local parse = function(t)
  local filename, lnum, col, text = find(t.value)

  local ok
  ok, lnum = pcall(tonumber, lnum)
  if not ok then
    lnum = nil
  end

  ok, col = pcall(tonumber, col)
  if not ok then
    col = nil
  end

  local text_ltrim = ltrim(text)
  local icon_name = "func"
  local name = ""
  local pos_parenthesis = string.find(text_ltrim, "%(")
  local leading_space = ""

  if pos_parenthesis == nil then
    pos_parenthesis = string.len(text_ltrim)
  end
  if text_ltrim:find("^def") then
    if text:find("^def") then
      icon_name = "func"
    else
      icon_name = "method"
    end
    name = string.sub(text_ltrim, 5, pos_parenthesis - 1)
  elseif text_ltrim:find("^# %%") then
    icon_name = "cell"
    name = string.sub(text_ltrim, 6)
  else
    icon_name = "class"
    name = string.sub(text_ltrim, 7, pos_parenthesis - 1)
  end
 

  t.filename = filename
  t.lnum = lnum
  t.col = string.len(text) - string.len(text_ltrim) + 1
  t.text = name
  t.icon_name = icon_name
  if t.col > 1 then
    leading_space = string.sub(text, 0, t.col - 1)
  end
  t.leading_space = leading_space

  return { filename, lnum, col, text, icon_name, leading_space}
end

local make_entry_outline = function(opts)
  local mt_vimgrep_entry

  opts = opts or {}

  local disable_devicons = opts.disable_devicons

  local execute_keys = {
    path = function(t)
      if Path:new(t.filename):is_absolute() then
        return t.filename, false
      else
        return Path:new({ t.cwd, t.filename }):absolute(), false
      end
    end,

    filename = function(t)
      return parse(t)[1], true
    end,

    lnum = function(t)
      return parse(t)[2], true
    end,

    col = function(t)
      return parse(t)[3], true
    end,

    text = function(t)
      return parse(t)[4], true
    end,

    icon_name = function(t)
      return parse(t)[5], true
    end,

    leading_space = function(t)
      return parse(t)[6], true
    end,
  }

  mt_vimgrep_entry = {
    cwd = vim.fn.expand(opts.cwd or vim.loop.cwd()),

    display = function(entry)
      local icon = lookup_icon[entry.icon_name].icon
      local color_name = lookup_icon[entry.icon_name].color_name
      return entry.leading_space .. icon .. " " .. entry.text, { { { entry.col, entry.col + 2 }, color_name } }
    end,

    __index = function(t, k)
      local raw = rawget(mt_vimgrep_entry, k)
      if raw then
        return raw
      end

      local executor = rawget(execute_keys, k)
      if executor then
        local val, save = executor(t)
        if save then
          rawset(t, k, val)
        end
        return val
      end

      return rawget(t, rawget(lookup_keys, k))
    end,
  }

  return function(line)
    return setmetatable({ line }, mt_vimgrep_entry)
  end
end

local outline_file = function(opts)
  local vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
  opts.entry_maker = make_entry_outline(opts)

  local find_outline_cmd = vim.tbl_flatten {
      vimgrep_arguments,
      "--",
      "(^[ ]*# %%.*)|(^[ ]*def ([_a-z][a-zA-z_0-9]*)\\()|(^[ ]*class ([A-Z][a-zA-Z_0-9]*)((\\()|:))",
      vim.fn.expand('%:p'),
  }

  pickers.new(opts, {
    prompt_title = "Outline for python",
    finder = finders.new_oneshot_job(find_outline_cmd, opts),
    previewer = conf.grep_previewer(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function(prompt_bufnr)
        local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          vim.api.nvim_win_set_cursor(0, { selection.lnum, selection.col })
      end)
    return true
  end,
  }):find()
end

return telescope.register_extension {
  exports = {
    outline_file = outline_file
  }
}
