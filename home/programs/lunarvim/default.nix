{ config, pkgs, lib, vars, colors, ... }:

let
in
{
  home-manager.users.${vars.username} = {
    # LunarVim is installed via home.packages in home.nix

    # LunarVim configuration (config.lua)
    home.file.".config/lvim/config.lua".text = ''
      -- LunarVim Configuration
      -- With Catppuccin theme and 60% transparency

      --[[
      ╔══════════════════════════════════════════════════════════════════════╗
      ║                         GENERAL SETTINGS                             ║
      ╚══════════════════════════════════════════════════════════════════════╝
      ]]

      -- General
      lvim.log.level = "warn"
      lvim.format_on_save = true
      lvim.lint_on_save = true

      -- Leader key
      lvim.leader = "space"

      -- Colorscheme with transparency
      lvim.colorscheme = "catppuccin-mocha"
      lvim.transparent_window = true

      -- Font (for Neovide or GUI)
      vim.o.guifont = "${colors.fonts.monospace}:h14"

      --[[
      ╔══════════════════════════════════════════════════════════════════════╗
      ║                         VIM OPTIONS                                  ║
      ╚══════════════════════════════════════════════════════════════════════╝
      ]]

      local opt = vim.opt

      -- Line numbers
      opt.number = true
      opt.relativenumber = true

      -- Indentation
      opt.tabstop = 2
      opt.shiftwidth = 2
      opt.expandtab = true
      opt.smartindent = true
      opt.autoindent = true

      -- Search
      opt.ignorecase = true
      opt.smartcase = true
      opt.hlsearch = true
      opt.incsearch = true

      -- Appearance
      opt.termguicolors = true
      opt.cursorline = true
      opt.signcolumn = "yes"
      opt.scrolloff = 8
      opt.sidescrolloff = 8
      opt.wrap = false

      -- Split behavior
      opt.splitbelow = true
      opt.splitright = true

      -- Clipboard
      opt.clipboard = "unnamedplus"

      -- Mouse
      opt.mouse = "a"

      -- Undo
      opt.undofile = true
      opt.undolevels = 10000

      -- Performance
      opt.updatetime = 250
      opt.timeoutlen = 300

      -- Completion
      opt.completeopt = "menu,menuone,noselect"

      -- Fold
      opt.foldmethod = "expr"
      opt.foldexpr = "nvim_treesitter#foldexpr()"
      opt.foldenable = false

      --[[
      ╔══════════════════════════════════════════════════════════════════════╗
      ║                         TRANSPARENCY                                 ║
      ╚══════════════════════════════════════════════════════════════════════╝
      ]]

      -- Make background transparent (60% opacity effect)
      -- This requires a compositor like picom, hyprland, etc.
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          -- Main backgrounds
          vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
          vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
          vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
          vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })

          -- Sign column and line numbers
          vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
          vim.api.nvim_set_hl(0, "LineNr", { bg = "none" })
          vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "none" })

          -- Status line
          vim.api.nvim_set_hl(0, "StatusLine", { bg = "none" })
          vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "none" })

          -- Tab line
          vim.api.nvim_set_hl(0, "TabLine", { bg = "none" })
          vim.api.nvim_set_hl(0, "TabLineFill", { bg = "none" })
          vim.api.nvim_set_hl(0, "TabLineSel", { bg = "none" })

          -- Vertical split
          vim.api.nvim_set_hl(0, "VertSplit", { bg = "none" })
          vim.api.nvim_set_hl(0, "WinSeparator", { bg = "none" })

          -- End of buffer
          vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })

          -- Popup menu
          vim.api.nvim_set_hl(0, "Pmenu", { bg = "none" })
          vim.api.nvim_set_hl(0, "PmenuSel", { bg = "${colors.colors.surface1}" })

          -- NvimTree
          vim.api.nvim_set_hl(0, "NvimTreeNormal", { bg = "none" })
          vim.api.nvim_set_hl(0, "NvimTreeNormalNC", { bg = "none" })
          vim.api.nvim_set_hl(0, "NvimTreeWinSeparator", { bg = "none", fg = "${colors.colors.surface0}" })

          -- Telescope
          vim.api.nvim_set_hl(0, "TelescopeNormal", { bg = "none" })
          vim.api.nvim_set_hl(0, "TelescopeBorder", { bg = "none", fg = "${colors.colors.accent}" })
          vim.api.nvim_set_hl(0, "TelescopePromptNormal", { bg = "none" })
          vim.api.nvim_set_hl(0, "TelescopePromptBorder", { bg = "none", fg = "${colors.colors.accent}" })
          vim.api.nvim_set_hl(0, "TelescopeResultsNormal", { bg = "none" })
          vim.api.nvim_set_hl(0, "TelescopeResultsBorder", { bg = "none", fg = "${colors.colors.surface1}" })
          vim.api.nvim_set_hl(0, "TelescopePreviewNormal", { bg = "none" })
          vim.api.nvim_set_hl(0, "TelescopePreviewBorder", { bg = "none", fg = "${colors.colors.surface1}" })

          -- Which-key
          vim.api.nvim_set_hl(0, "WhichKeyFloat", { bg = "none" })

          -- Lualine (handled separately in lualine config)
        end,
      })

      --[[
      ╔══════════════════════════════════════════════════════════════════════╗
      ║                         KEYBINDINGS                                  ║
      ╚══════════════════════════════════════════════════════════════════════╝
      ]]

      -- Better window navigation
      lvim.keys.normal_mode["<C-h>"] = "<C-w>h"
      lvim.keys.normal_mode["<C-j>"] = "<C-w>j"
      lvim.keys.normal_mode["<C-k>"] = "<C-w>k"
      lvim.keys.normal_mode["<C-l>"] = "<C-w>l"

      -- Resize windows with arrows
      lvim.keys.normal_mode["<C-Up>"] = ":resize -2<CR>"
      lvim.keys.normal_mode["<C-Down>"] = ":resize +2<CR>"
      lvim.keys.normal_mode["<C-Left>"] = ":vertical resize -2<CR>"
      lvim.keys.normal_mode["<C-Right>"] = ":vertical resize +2<CR>"

      -- Buffer navigation
      lvim.keys.normal_mode["<S-l>"] = ":BufferLineCycleNext<CR>"
      lvim.keys.normal_mode["<S-h>"] = ":BufferLineCyclePrev<CR>"
      lvim.keys.normal_mode["<leader>bd"] = ":BufferKill<CR>"

      -- Move text up and down
      lvim.keys.normal_mode["<A-j>"] = ":m .+1<CR>=="
      lvim.keys.normal_mode["<A-k>"] = ":m .-2<CR>=="
      lvim.keys.visual_mode["<A-j>"] = ":m '>+1<CR>gv=gv"
      lvim.keys.visual_mode["<A-k>"] = ":m '<-2<CR>gv=gv"

      -- Stay in indent mode
      lvim.keys.visual_mode["<"] = "<gv"
      lvim.keys.visual_mode[">"] = ">gv"

      -- Clear search highlighting
      lvim.keys.normal_mode["<leader>h"] = ":nohlsearch<CR>"

      -- Save and quit shortcuts
      lvim.keys.normal_mode["<C-s>"] = ":w<CR>"
      lvim.keys.normal_mode["<C-q>"] = ":q<CR>"

      -- Toggle transparency (for testing)
      lvim.keys.normal_mode["<leader>tt"] = function()
        local bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
        if bg then
          vim.cmd("hi Normal guibg=NONE ctermbg=NONE")
          vim.cmd("hi NormalNC guibg=NONE ctermbg=NONE")
          vim.notify("Transparency enabled")
        else
          vim.cmd("colorscheme " .. lvim.colorscheme)
          vim.notify("Transparency disabled")
        end
      end

      --[[
      ╔══════════════════════════════════════════════════════════════════════╗
      ║                         PLUGINS                                      ║
      ╚══════════════════════════════════════════════════════════════════════╝
      ]]

      lvim.plugins = {
        -- Catppuccin colorscheme
        {
          "catppuccin/nvim",
          name = "catppuccin",
          priority = 1000,
          config = function()
            require("catppuccin").setup({
              flavour = "mocha",
              background = {
                light = "latte",
                dark = "mocha",
              },
              transparent_background = true, -- 60% transparency effect
              show_end_of_buffer = false,
              term_colors = true,
              dim_inactive = {
                enabled = false,
              },
              styles = {
                comments = { "italic" },
                conditionals = { "italic" },
                loops = {},
                functions = {},
                keywords = {},
                strings = {},
                variables = {},
                numbers = {},
                booleans = {},
                properties = {},
                types = {},
                operators = {},
              },
              color_overrides = {
                mocha = {
                  -- Use standard Catppuccin colors
                  -- Custom accent is handled via integrations
                },
              },
              custom_highlights = function(C)
                -- C is the catppuccin color table
                return {
                  -- Custom highlights for specific elements (no alpha channel)
                  CursorLine = { bg = C.surface0 },
                  Visual = { bg = C.surface1 },
                  Search = { bg = C.blue, fg = C.base },
                }
              end,
              integrations = {
                cmp = true,
                gitsigns = true,
                nvimtree = true,
                treesitter = true,
                telescope = {
                  enabled = true,
                },
                which_key = true,
                indent_blankline = {
                  enabled = true,
                  colored_indent_levels = false,
                },
                native_lsp = {
                  enabled = true,
                  virtual_text = {
                    errors = { "italic" },
                    hints = { "italic" },
                    warnings = { "italic" },
                    information = { "italic" },
                  },
                  underlines = {
                    errors = { "underline" },
                    hints = { "underline" },
                    warnings = { "underline" },
                    information = { "underline" },
                  },
                },
              },
            })
          end,
        },

        -- Better syntax highlighting
        {
          "nvim-treesitter/nvim-treesitter-context",
          config = function()
            require("treesitter-context").setup({
              enable = true,
              max_lines = 3,
              trim_scope = "outer",
            })
          end,
        },

        -- Indent guides
        {
          "lukas-reineke/indent-blankline.nvim",
          main = "ibl",
          opts = {
            indent = {
              char = "│",
              highlight = "IblIndent",
            },
            scope = {
              enabled = true,
              show_start = true,
              show_end = false,
              highlight = "IblScope",
            },
          },
        },

        -- Git integration
        {
          "lewis6991/gitsigns.nvim",
          config = function()
            require("gitsigns").setup({
              signs = {
                add = { text = "│" },
                change = { text = "│" },
                delete = { text = "_" },
                topdelete = { text = "‾" },
                changedelete = { text = "~" },
                untracked = { text = "┆" },
              },
              current_line_blame = true,
              current_line_blame_opts = {
                virt_text = true,
                virt_text_pos = "eol",
                delay = 1000,
              },
            })
          end,
        },

        -- Smooth scrolling
        {
          "karb94/neoscroll.nvim",
          config = function()
            require("neoscroll").setup({
              mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "zt", "zz", "zb" },
              hide_cursor = true,
              stop_eof = true,
              respect_scrolloff = false,
              cursor_scrolls_alone = true,
            })
          end,
        },

        -- Better escape - removed due to deprecation warnings
        -- Use jk/jj mappings manually if needed:
        -- vim.keymap.set("i", "jk", "<Esc>")
        -- vim.keymap.set("i", "jj", "<Esc>")

        -- Todo comments
        {
          "folke/todo-comments.nvim",
          dependencies = { "nvim-lua/plenary.nvim" },
          config = function()
            require("todo-comments").setup({
              signs = true,
              keywords = {
                FIX = { icon = " ", color = "error" },
                TODO = { icon = " ", color = "info" },
                HACK = { icon = " ", color = "warning" },
                WARN = { icon = " ", color = "warning" },
                PERF = { icon = " ", color = "default" },
                NOTE = { icon = " ", color = "hint" },
                TEST = { icon = "⏲ ", color = "test" },
              },
            })
          end,
        },

        -- Color highlighter
        {
          "NvChad/nvim-colorizer.lua",
          config = function()
            require("colorizer").setup({
              filetypes = { "*" },
              user_default_options = {
                RGB = true,
                RRGGBB = true,
                names = true,
                RRGGBBAA = true,
                AARRGGBB = true,
                rgb_fn = true,
                hsl_fn = true,
                css = true,
                css_fn = true,
                mode = "background",
                tailwind = true,
                virtualtext = "■",
              },
            })
          end,
        },

        -- Surround
        {
          "kylechui/nvim-surround",
          version = "*",
          event = "VeryLazy",
          config = function()
            require("nvim-surround").setup({})
          end,
        },

        -- Auto pairs
        {
          "windwp/nvim-autopairs",
          config = function()
            require("nvim-autopairs").setup({
              check_ts = true,
              ts_config = {
                lua = { "string", "source" },
                javascript = { "string", "template_string" },
              },
            })
          end,
        },

        --[[
        ╔══════════════════════════════════════════════════════════════════════╗
        ║                         PYTHON PLUGINS                               ║
        ╚══════════════════════════════════════════════════════════════════════╝
        ]]

        -- Python debugging
        {
          "mfussenegger/nvim-dap-python",
          ft = "python",
          dependencies = {
            "mfussenegger/nvim-dap",
          },
          config = function()
            require("dap-python").setup("python3")
          end,
        },

        -- Python virtual environment selector
        {
          "linux-cultist/venv-selector.nvim",
          dependencies = {
            "neovim/nvim-lspconfig",
            "mfussenegger/nvim-dap",
            "mfussenegger/nvim-dap-python",
            "nvim-telescope/telescope.nvim",
          },
          branch = "regexp",
          config = function()
            require("venv-selector").setup({
              name = { "venv", ".venv", "env", ".env" },
              auto_refresh = true,
            })
          end,
          keys = {
            { "<leader>vs", "<cmd>VenvSelect<cr>", desc = "Select Python venv" },
            { "<leader>vc", "<cmd>VenvSelectCached<cr>", desc = "Select cached venv" },
          },
        },

        -- Python indent
        {
          "Vimjas/vim-python-pep8-indent",
          ft = "python",
        },

        -- Python docstrings
        {
          "danymat/neogen",
          dependencies = "nvim-treesitter/nvim-treesitter",
          config = function()
            require("neogen").setup({
              enabled = true,
              languages = {
                python = {
                  template = {
                    annotation_convention = "google_docstrings",
                  },
                },
                csharp = {
                  template = {
                    annotation_convention = "xmldoc",
                  },
                },
              },
            })
          end,
          keys = {
            { "<leader>ng", "<cmd>Neogen<cr>", desc = "Generate docstring" },
          },
        },

        --[[
        ╔══════════════════════════════════════════════════════════════════════╗
        ║                         C# PLUGINS                                   ║
        ╚══════════════════════════════════════════════════════════════════════╝
        ]]

        -- C# extended LSP support
        {
          "Hoffs/omnisharp-extended-lsp.nvim",
          ft = { "cs", "csharp" },
        },

        -- .NET debugging
        {
          "mfussenegger/nvim-dap",
          config = function()
            local dap = require("dap")

            -- .NET Core debugger configuration
            dap.adapters.coreclr = {
              type = "executable",
              command = "netcoredbg",
              args = { "--interpreter=vscode" },
            }

            dap.configurations.cs = {
              {
                type = "coreclr",
                name = "Launch - netcoredbg",
                request = "launch",
                program = function()
                  return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
                end,
              },
            }
          end,
        },

        -- DAP UI for debugging
        {
          "rcarriga/nvim-dap-ui",
          dependencies = {
            "mfussenegger/nvim-dap",
            "nvim-neotest/nvim-nio",
          },
          config = function()
            local dap, dapui = require("dap"), require("dapui")
            dapui.setup()

            dap.listeners.after.event_initialized["dapui_config"] = function()
              dapui.open()
            end
            dap.listeners.before.event_terminated["dapui_config"] = function()
              dapui.close()
            end
            dap.listeners.before.event_exited["dapui_config"] = function()
              dapui.close()
            end
          end,
          keys = {
            { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
            { "<leader>de", function() require("dapui").eval() end, desc = "DAP Eval", mode = { "n", "v" } },
          },
        },

        -- Virtual text for debugger
        {
          "theHamsta/nvim-dap-virtual-text",
          dependencies = { "mfussenegger/nvim-dap", "nvim-treesitter/nvim-treesitter" },
          config = function()
            require("nvim-dap-virtual-text").setup()
          end,
        },

        -- Neotest for testing
        {
          "nvim-neotest/neotest",
          dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-treesitter/nvim-treesitter",
            "antoinemadec/FixCursorHold.nvim",
            "nvim-neotest/neotest-python",
            "Issafalcon/neotest-dotnet",
          },
          config = function()
            require("neotest").setup({
              adapters = {
                require("neotest-python")({
                  dap = { justMyCode = false },
                  runner = "pytest",
                }),
                require("neotest-dotnet"),
              },
            })
          end,
          keys = {
            { "<leader>tr", function() require("neotest").run.run() end, desc = "Run nearest test" },
            { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file tests" },
            { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle test summary" },
            { "<leader>to", function() require("neotest").output.open() end, desc = "Show test output" },
          },
        },
      }

      --[[
      ╔══════════════════════════════════════════════════════════════════════╗
      ║                         BUILT-IN PLUGINS CONFIG                      ║
      ╚══════════════════════════════════════════════════════════════════════╝
      ]]

      -- NvimTree
      lvim.builtin.nvimtree.setup.view.side = "left"
      lvim.builtin.nvimtree.setup.view.width = 30
      lvim.builtin.nvimtree.setup.renderer.icons.show.git = true
      lvim.builtin.nvimtree.setup.renderer.highlight_git = true
      lvim.builtin.nvimtree.setup.update_focused_file.enable = true

      -- Telescope
      lvim.builtin.telescope.defaults.layout_strategy = "horizontal"
      lvim.builtin.telescope.defaults.layout_config = {
        horizontal = {
          prompt_position = "top",
          preview_width = 0.55,
        },
        width = 0.87,
        height = 0.80,
        preview_cutoff = 120,
      }
      lvim.builtin.telescope.defaults.sorting_strategy = "ascending"
      lvim.builtin.telescope.defaults.winblend = 0 -- Transparent

      -- Bufferline
      lvim.builtin.bufferline.options.separator_style = "thin"
      lvim.builtin.bufferline.options.always_show_bufferline = true

      -- Lualine (transparent)
      lvim.builtin.lualine.options.theme = "catppuccin"
      lvim.builtin.lualine.options.section_separators = { left = "", right = "" }
      lvim.builtin.lualine.options.component_separators = { left = "", right = "" }

      -- Terminal
      lvim.builtin.terminal.active = true
      lvim.builtin.terminal.direction = "horizontal"
      lvim.builtin.terminal.size = 15

      -- Alpha (dashboard)
      lvim.builtin.alpha.active = true
      lvim.builtin.alpha.mode = "dashboard"

      -- Project
      lvim.builtin.project.detection_methods = { "pattern", "lsp" }
      lvim.builtin.project.patterns = { ".git", "Makefile", "package.json", "Cargo.toml", "flake.nix" }

      --[[
      ╔══════════════════════════════════════════════════════════════════════╗
      ║                         LSP CONFIGURATION                            ║
      ╚══════════════════════════════════════════════════════════════════════╝
      ]]

      -- Note: Formatters and linters are disabled due to null-ls deprecation
      -- LunarVim's built-in LSP handles most functionality
      -- You can manually configure formatters if needed

      -- Disable automatic LSP installation (managed by NixOS)
      lvim.lsp.installer.setup.automatic_installation = false

      -- Skip automatic server setup for servers we configure manually
      vim.list_extend(lvim.lsp.automatic_configuration.skipped_servers, {
        "nil_ls", "pyright", "omnisharp",
      })

      -- Manual LSP setup for Nix
      local lspconfig = require("lspconfig")
      lspconfig.nil_ls.setup({
        settings = {
          ["nil"] = {
            formatting = {
              command = { "nixpkgs-fmt" },
            },
          },
        },
      })

      --[[
      ╔══════════════════════════════════════════════════════════════════════╗
      ║                         PYTHON DEVELOPMENT                           ║
      ╚══════════════════════════════════════════════════════════════════════╝
      ]]

      -- Python LSP (pyright)
      lspconfig.pyright.setup({
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "basic",
              autoImportCompletions = true,
              diagnosticMode = "workspace",
            },
          },
        },
      })

      --[[
      ╔══════════════════════════════════════════════════════════════════════╗
      ║                         C# DEVELOPMENT                               ║
      ╚══════════════════════════════════════════════════════════════════════╝
      ]]

      -- C# LSP (OmniSharp)
      lspconfig.omnisharp.setup({
        cmd = { "OmniSharp", "--languageserver", "--hostPID", tostring(vim.fn.getpid()) },
        settings = {
          FormattingOptions = {
            EnableEditorConfigSupport = true,
          },
          RoslynExtensionsOptions = {
            EnableAnalyzersSupport = true,
            EnableImportCompletion = true,
          },
        },
      })

      --[[
      ╔══════════════════════════════════════════════════════════════════════╗
      ║                         AUTOCOMMANDS                                 ║
      ╚══════════════════════════════════════════════════════════════════════╝
      ]]

      -- Highlight on yank
      vim.api.nvim_create_autocmd("TextYankPost", {
        callback = function()
          vim.highlight.on_yank({ higroup = "Visual", timeout = 200 })
        end,
      })

      -- Remove whitespace on save
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*",
        command = [[%s/\s\+$//e]],
      })

      -- Return to last edit position
      vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function()
          local mark = vim.api.nvim_buf_get_mark(0, '"')
          local lcount = vim.api.nvim_buf_line_count(0)
          if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
          end
        end,
      })

      -- Set filetype for specific files
      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = { "*.nix" },
        command = "setfiletype nix",
      })

      -- Apply transparency after colorscheme loads
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          vim.cmd("doautocmd ColorScheme")
        end,
      })
    '';
  };
}
