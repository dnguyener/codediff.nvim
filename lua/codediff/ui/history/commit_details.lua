-- Floating commit details owned by a history session.
local M = {}

local function is_valid(winid)
  return winid and vim.api.nvim_win_is_valid(winid)
end

function M.is_open(session)
  return session and is_valid(session._commit_details_win) or false
end

function M.close(session)
  if not session then
    return
  end
  if is_valid(session._commit_details_win) then
    vim.api.nvim_win_close(session._commit_details_win, true)
  end
  session._commit_details_win = nil
  session._commit_details_buf = nil
end

local function lines_for(details)
  local lines = {
    "Commit: " .. details.hash,
    "Author: " .. details.author,
    "Date: " .. details.authored_date,
    "Refs: " .. (details.ref_names or "(none)"),
    "Subject: " .. details.subject,
    "",
    "Message:",
  }
  vim.list_extend(lines, vim.split(details.message, "\n", { plain = true, trimempty = false }))
  return lines
end

local function dimensions(lines)
  local widest = 0
  for _, line in ipairs(lines) do
    widest = math.max(widest, vim.fn.strdisplaywidth(line))
  end
  local max_width = math.max(1, vim.o.columns - 4)
  local max_height = math.max(1, vim.o.lines - 4)
  return math.min(math.max(widest, 40), max_width), math.min(#lines, max_height)
end

function M.open(session, details, toggle_keys)
  M.close(session)

  local lines = lines_for(details)
  local width, height = dimensions(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "codediff-commit-details"
  vim.bo[buf].modifiable = false

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Commit Details ",
    title_pos = "center",
  })
  vim.wo[win].cursorline = false
  vim.wo[win].wrap = true
  vim.wo[win].winhighlight = "NormalFloat:NormalFloat"

  session._commit_details_win = win
  session._commit_details_buf = buf

  local function close()
    M.close(session)
  end
  for _, key in ipairs(vim.list_extend({ "q", "<Esc>" }, toggle_keys or {})) do
    vim.keymap.set("n", key, close, { buffer = buf, nowait = true, silent = true })
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    once = true,
    callback = function(args)
      if tonumber(args.match) == win and session._commit_details_win == win then
        session._commit_details_win = nil
        session._commit_details_buf = nil
      end
    end,
  })
end

return M
