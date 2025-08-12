local M = {}

-- Claude Code integration with built-in Neovim diffs
M.setup = function()
  -- Check if claude is available
  if vim.fn.executable("claude") == 0 then
    vim.notify("claude not found in PATH. Install with: npm install -g @anthropic-ai/claude-code", vim.log.levels.ERROR)
    return
  end

  -- Create Claude Code commands
  vim.api.nvim_create_user_command("Claude", function(opts)
    M.run_claude_terminal(opts.args)
  end, {
    nargs = "*",
    desc = "Run Claude in terminal",
    complete = function(arglead, cmdline, cursorpos)
      return { "--help", "--version", "--model sonnet", "--model opus" }
    end,
  })

  vim.api.nvim_create_user_command("ClaudeDiff", function(opts)
    M.analyze_file_with_diff(opts.args)
  end, {
    nargs = "*",
    desc = "Analyze current file with Claude and show diff",
  })

  vim.api.nvim_create_user_command("ClaudeApply", function()
    M.apply_claude_changes()
  end, { desc = "Apply Claude changes from diff" })

  vim.api.nvim_create_user_command("ClaudeReject", function()
    M.reject_claude_changes()
  end, { desc = "Reject Claude changes and close diff" })
end

-- Store original content and temp files for diff operations
M.diff_state = {
  original_file = nil,
  temp_file = nil,
  original_content = nil,
  diff_buffers = {},
  diff_tab = nil,
}

-- Basic Claude runner (opens interactive terminal)
M.run_claude_terminal = function(args)
  local cmd = "claude"
  if args and args ~= "" then
    cmd = cmd .. " " .. args
  end

  vim.cmd("split | terminal " .. cmd)
end

M.analyze_file_with_diff = function(instruction)
  local current_file = vim.fn.expand("%:p")
  if current_file == "" or vim.bo.buftype ~= "" then
    vim.notify("No valid file open", vim.log.levels.WARN)
    return
  end

  -- Save current file first
  vim.cmd("write")

  -- Store original content
  M.diff_state.original_file = current_file
  M.diff_state.original_content = vim.fn.readfile(current_file)

  -- Create temp file with original content for comparison
  local file_extension = vim.fn.fnamemodify(current_file, ":e")
  M.diff_state.temp_file = vim.fn.tempname() .. "." .. file_extension
  vim.fn.writefile(M.diff_state.original_content, M.diff_state.temp_file)

  -- Get instruction from user if not provided
  if not instruction or instruction == "" then
    vim.ui.input({
      prompt = "Claude instruction: ",
      default = "Improve this code and fix any issues",
    }, function(input)
      if input and input ~= "" then
        M.run_claude_with_diff(current_file, input)
      end
    end)
  else
    M.run_claude_with_diff(current_file, instruction)
  end
end

M.run_claude_with_diff = function(file_path, instruction)
  -- Show loading message
  vim.notify("Running Claude analysis...", vim.log.levels.INFO)

  -- Claude will modify the file in place, so we'll run it and then check for changes
  local cmd = {
    "claude",
    "-p", -- print mode (headless)
    string.format(
      'Analyze and improve the file "%s". %s. Make the changes directly to the file.',
      file_path,
      instruction
    ),
  }

  vim.fn.jobstart(cmd, {
    cwd = vim.fn.fnamemodify(file_path, ":h"),
    on_exit = function(_, code)
      -- Small delay to ensure file operations are complete
      vim.defer_fn(function()
        if code == 0 then
          M.check_for_changes()
        else
          vim.notify("Claude failed with exit code: " .. code, vim.log.levels.ERROR)
          M.cleanup_temp_files()
        end
      end, 100)
    end,
    on_stderr = function(_, data)
      if data and #data > 0 and data[1] ~= "" then
        vim.notify("Claude: " .. table.concat(data, "\n"), vim.log.levels.WARN)
      end
    end,
  })
end

M.check_for_changes = function()
  -- Check if the original file was modified
  local current_content = vim.fn.readfile(M.diff_state.original_file)
  local original_content = M.diff_state.original_content

  if not vim.deep_equal(current_content, original_content) then
    -- File was modified, update temp file with new content for diff
    vim.fn.writefile(current_content, M.diff_state.temp_file)
    -- Restore original content to the actual file for diff view
    vim.fn.writefile(original_content, M.diff_state.original_file)
    vim.cmd("checktime") -- Reload the file in Neovim
    M.show_diff_view()
  else
    vim.notify("No changes were made by Claude", vim.log.levels.INFO)
    M.cleanup_temp_files()
  end
end

M.show_diff_view = function()
  local original_file = M.diff_state.original_file
  local temp_file = M.diff_state.temp_file

  -- Create a new tab for the diff view
  vim.cmd("tabnew")
  M.diff_state.diff_tab = vim.api.nvim_get_current_tabpage()

  -- Set up diff view
  vim.cmd("edit " .. vim.fn.fnameescape(original_file))
  local original_buf = vim.api.nvim_get_current_buf()
  vim.cmd("diffthis")

  vim.cmd("vsplit " .. vim.fn.fnameescape(temp_file))
  local modified_buf = vim.api.nvim_get_current_buf()
  vim.cmd("diffthis")

  -- Store buffer info for later operations
  M.diff_state.diff_buffers = {
    original = original_buf,
    modified = modified_buf,
  }

  -- Set buffer options for the temp file
  vim.api.nvim_buf_set_option(modified_buf, "buftype", "")
  vim.api.nvim_buf_set_option(modified_buf, "readonly", false)
  vim.api.nvim_buf_set_name(modified_buf, "Claude Changes - " .. vim.fn.fnamemodify(original_file, ":t"))

  -- Add helpful keymaps for the diff view
  M.setup_diff_keymaps()

  -- Show instructions
  vim.notify("Diff view opened. Use <leader>ca to apply changes, <leader>cr to reject", vim.log.levels.INFO)
  vim.notify("Navigation: ]c (next change), [c (prev change), do (get change), dp (put change)", vim.log.levels.INFO)
end

M.setup_diff_keymaps = function()
  local opts = { buffer = true, silent = true }

  -- Apply changes
  vim.keymap.set("n", "<leader>ca", function()
    M.apply_claude_changes()
  end, vim.tbl_extend("force", opts, { desc = "Apply Claude changes" }))

  -- Reject changes
  vim.keymap.set("n", "<leader>cr", function()
    M.reject_claude_changes()
  end, vim.tbl_extend("force", opts, { desc = "Reject Claude changes" }))

  -- Show help
  vim.keymap.set("n", "<leader>ch", function()
    local help_lines = {
      "Claude Diff View Help:",
      "",
      "Navigation:",
      "  ]c - Go to next change",
      "  [c - Go to previous change",
      "",
      "Editing:",
      "  do - Obtain diff hunk from other buffer (get change)",
      "  dp - Put diff hunk to other buffer (put change)",
      "",
      "Actions:",
      "  <leader>ca - Apply all changes and close diff",
      "  <leader>cr - Reject all changes and close diff",
      "  <leader>ch - Show this help",
      "",
      "You can also manually edit either side and save normally.",
    }

    local help_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
    vim.api.nvim_buf_set_option(help_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(help_buf, "filetype", "help")

    local help_win = vim.api.nvim_open_win(help_buf, true, {
      relative = "editor",
      width = 60,
      height = #help_lines + 2,
      col = math.floor((vim.o.columns - 60) / 2),
      row = math.floor((vim.o.lines - #help_lines) / 2),
      style = "minimal",
      border = "rounded",
      title = " Claude Help ",
      title_pos = "center",
    })

    vim.keymap.set("n", "q", function()
      vim.api.nvim_win_close(help_win, true)
    end, { buffer = help_buf, silent = true })

    vim.keymap.set("n", "<Esc>", function()
      vim.api.nvim_win_close(help_win, true)
    end, { buffer = help_buf, silent = true })
  end, vim.tbl_extend("force", opts, { desc = "Show Claude diff help" }))
end

M.apply_claude_changes = function()
  if not M.diff_state.temp_file or not M.diff_state.original_file then
    vim.notify("No active Claude diff session", vim.log.levels.WARN)
    return
  end

  -- Copy content from temp file to original file
  local temp_content = vim.fn.readfile(M.diff_state.temp_file)
  vim.fn.writefile(temp_content, M.diff_state.original_file)

  -- Reload the original file in all windows
  vim.cmd("checktime")

  -- Close diff view
  M.cleanup_diff()

  vim.notify("Claude changes applied successfully!", vim.log.levels.INFO)
end

M.reject_claude_changes = function()
  if not M.diff_state.original_file then
    vim.notify("No active Claude diff session", vim.log.levels.WARN)
    return
  end

  -- Restore original content (it should already be restored, but just in case)
  if M.diff_state.original_content then
    vim.fn.writefile(M.diff_state.original_content, M.diff_state.original_file)
    vim.cmd("checktime")
  end

  -- Close diff view
  M.cleanup_diff()

  vim.notify("Claude changes rejected", vim.log.levels.INFO)
end

M.cleanup_diff = function()
  -- Close diff tab if it exists
  if M.diff_state.diff_tab then
    local current_tab = vim.api.nvim_get_current_tabpage()
    if current_tab == M.diff_state.diff_tab then
      vim.cmd("tabclose")
    else
      vim.cmd("tabclose " .. M.diff_state.diff_tab)
    end
  end

  M.cleanup_temp_files()
end

M.cleanup_temp_files = function()
  -- Clean up temp file
  if M.diff_state.temp_file then
    vim.fn.delete(M.diff_state.temp_file)
  end

  -- Reset state
  M.diff_state = {
    original_file = nil,
    temp_file = nil,
    original_content = nil,
    diff_buffers = {},
    diff_tab = nil,
  }
end

-- Enhanced selection analysis with diff
M.analyze_selection_with_diff = function()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  if #lines == 0 then
    vim.notify("No selection found", vim.log.levels.WARN)
    return
  end

  local current_file = vim.fn.expand("%:p")
  local line_range = string.format("lines %d-%d", start_pos[2], end_pos[2])

  vim.ui.input({
    prompt = "Instructions for selected code: ",
    default = "Improve the selected code section",
  }, function(input)
    if input and input ~= "" then
      local full_instruction = string.format("%s (focus on %s in the file)", input, line_range)
      M.analyze_file_with_diff(full_instruction)
    end
  end)
end

-- Project analysis (non-diff, since it affects multiple files)
M.analyze_project = function()
  local project_root = vim.fn.getcwd()

  vim.ui.input({
    prompt = "Instructions for project analysis: ",
    default = "Analyze this project and suggest improvements",
  }, function(input)
    if input and input ~= "" then
      vim.notify("Running Claude on project: " .. project_root, vim.log.levels.INFO)

      local cmd = string.format("claude -p '%s'", input)
      vim.cmd("split | terminal " .. cmd)
    end
  end)
end

-- Quick file explanation (non-diff)
M.explain_file = function()
  local current_file = vim.fn.expand("%:p")
  if current_file == "" or vim.bo.buftype ~= "" then
    vim.notify("No valid file open", vim.log.levels.WARN)
    return
  end

  local cmd = string.format("claude -p 'Explain this file: %s'", current_file)
  vim.cmd("split | terminal " .. cmd)
end

return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>c", group = "claude" },
      },
    },
  },

  {
    "nvim-lua/plenary.nvim",
    config = function()
      M.setup()
    end,
    keys = {
      -- Main Claude commands
      { "<leader>cc", "<cmd>Claude<cr>", desc = "Claude: Interactive terminal" },
      { "<leader>cd", "<cmd>ClaudeDiff<cr>", desc = "Claude: Analyze with diff" },

      -- File analysis with diff
      {
        "<leader>cf",
        function()
          M.analyze_file_with_diff()
        end,
        desc = "Claude: Current file with diff",
      },

      -- Selection analysis with diff
      {
        "<leader>cs",
        function()
          M.analyze_selection_with_diff()
        end,
        mode = "v",
        desc = "Claude: Selection with diff",
      },

      -- Project analysis (terminal output)
      {
        "<leader>cp",
        function()
          M.analyze_project()
        end,
        desc = "Claude: Project analysis",
      },

      -- File explanation (terminal output)
      {
        "<leader>ce",
        function()
          M.explain_file()
        end,
        desc = "Claude: Explain current file",
      },

      -- Diff operations (active during diff view)
      { "<leader>ca", "<cmd>ClaudeApply<cr>", desc = "Claude: Apply changes" },
      { "<leader>cr", "<cmd>ClaudeReject<cr>", desc = "Claude: Reject changes" },

      -- Custom instruction with diff
      {
        "<leader>ci",
        function()
          vim.ui.input({ prompt = "Claude instruction: " }, function(input)
            if input and input ~= "" then
              M.analyze_file_with_diff(input)
            end
          end)
        end,
        desc = "Claude: Custom instruction with diff",
      },

      -- Quick terminal access for complex tasks
      {
        "<leader>ct",
        function()
          local cwd = vim.fn.getcwd()
          vim.ui.input({
            prompt = "Claude command (or press Enter for interactive): ",
            default = "",
          }, function(input)
            local cmd = input and input ~= "" and ("claude -p '" .. input .. "'") or "claude"
            vim.cmd("split | terminal " .. cmd)
          end)
        end,
        desc = "Claude: Custom terminal command",
      },
    },
  },
}
