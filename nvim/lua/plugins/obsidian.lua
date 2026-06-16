return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = true,
  -- ft = "markdown",
  event = {
    "BufReadPre " .. vim.fn.expand("~") .. "/gh/notes/content/*.md",
    "BufNewFile " .. vim.fn.expand("~") .. "/gh/notes/content/*.md",
  },
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",

    -- see below for full list of optional dependencies 👇
  },
  keys = {
    { "<leader>ot", "<cmd>Obsidian template default.md<cr>", desc = "Insert default template" },
  },
  opts = {
    legacy_commands = false,
    workspaces = {
      {
        name = "personal",
        path = "~/gh/notes/content",
      },
    },
    templates = {
      folder = "templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
    },
    note_id_func = function(title)
      if title ~= nil and title ~= "" then
        return title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
      end
      local s = ""
      for _ = 1, 4 do
        s = s .. string.char(math.random(65, 90))
      end
      return s
    end,
    frontmatter = {
      func = function(note)
        local out = { title = note.title, index = "" }

        if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
          for k, v in pairs(note.metadata) do
            out[k] = v
          end
        end

        return out
      end,
    },
    attachments = {
      folder = "attachments",
    },
    completion = {
      min_chars = 1,
    },
  },
  config = function(_, opts)
    require("obsidian").setup(opts)

    vim.api.nvim_create_autocmd("BufNewFile", {
      pattern = vim.fn.expand("~") .. "/gh/notes/content/*.md",
      callback = function(args)
        if args.file:match("/templates/") then
          return
        end
        vim.schedule(function()
          local buf = args.buf
          if not vim.api.nvim_buf_is_valid(buf) then
            return
          end
          local last = vim.api.nvim_buf_line_count(buf)
          vim.api.nvim_buf_set_lines(buf, last, last, false, {
            "",
            "",
            "",
            "---",
            "",
            "related:",
            "- ",
          })
        end)
      end,
    })
  end,
}
