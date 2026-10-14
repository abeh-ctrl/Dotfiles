# vis.nix — Home Manager module for the vis editor
# Import from home.nix:  imports = [ ./vis.nix ];
{ pkgs, lib, ... }:

let
  # vis-lspc: LSP client plugin for vis.
  # First build will fail with a hash mismatch; paste the "got:" hash below.
  vis-lspc-src = pkgs.fetchFromGitHub {
    owner = "erf";
    repo = "vis-lspc";
    rev = "master";
    hash = "sha256-3eGAtPep4ZcwH1PTOee4Vd2+HD9Isg4qwcuIJK8Lgok=";
  };

  # Current vis passes PROCESS_RESPONSE args as (name, type, code, buffer);
  # upstream vis-lspc still expects (name, buffer, type). Patch it to match.
  vis-lspc = pkgs.runCommand "vis-lspc-patched" { } ''
    cp -r ${vis-lspc-src} $out
    chmod -R u+w $out
    substituteInPlace $out/init.lua \
      --replace-fail "function(name, msg, event)" "function(name, event, code, msg)" \
      --replace-fail "'language server exited with: ' .. msg" "'language server exited with: ' .. tostring(code)" \
      --replace-fail "'language server received signal: ' .. msg" "'language server received signal: ' .. tostring(code)"
  '';
in
{
  home.packages = with pkgs; [
    vis

    # clipboard backends (vis-clipboard picks whichever matches the session)
    wl-clipboard
    xclip

    # used by vis's :open menu, :fmt helpers and general editing
    fzf
    ripgrep
    file

    # language servers
    rust-analyzer
    clang-tools # clangd + clang-format
    gopls
    nixd
    lua-language-server

    # formatters used by :fmt below
    nixfmt # RFC-style formatter (older channels: nixfmt-rfc-style)
    stylua
    gotools # goimports
    rustfmt
  ];

  # home.sessionVariables.EDITOR = "vis";

  xdg.configFile."vis/plugins/vis-lspc".source = vis-lspc;

  xdg.configFile."vis/visrc.lua".text = ''
    require('vis')

    ---------------------------------------------------------------------
    -- LSP
    ---------------------------------------------------------------------
    local lspc = require('plugins/vis-lspc')

    lspc.ls_map.rust   = { name = 'rust-analyzer',      cmd = 'rust-analyzer' }
    lspc.ls_map.ansi_c = { name = 'clangd',             cmd = 'clangd --background-index' }
    lspc.ls_map.cpp    = { name = 'clangd',             cmd = 'clangd --background-index' }
    lspc.ls_map.go     = { name = 'gopls',              cmd = 'gopls' }
    lspc.ls_map.nix    = { name = 'nixd',               cmd = 'nixd' }
    lspc.ls_map.lua    = { name = 'lua-language-server', cmd = 'lua-language-server' }

    ---------------------------------------------------------------------
    -- Global options
    ---------------------------------------------------------------------
    -- (no theme line: vis picks its default theme automatically)

    -- per-language indentation (suckless-style tabs for C and Go)
    local indent = {
      ansi_c = { tabs = true,  width = 8 },
      cpp    = { tabs = true,  width = 8 },
      go     = { tabs = true,  width = 4 },
      rust   = { tabs = false, width = 4 },
      nix    = { tabs = false, width = 2 },
      lua    = { tabs = false, width = 2 },
    }

    vis.events.subscribe(vis.events.WIN_OPEN, function(win)
      -- pcall each option so an unsupported name never aborts the rest
      local function set(k, v)
        pcall(function() win.options[k] = v end)
      end

      local cfg = indent[win.syntax] or { tabs = false, width = 4 }
      set('numbers',     true)
      set('cursorline',  true)
      set('autoindent',  true)
      set('colorcolumn', 80)
      set('tabwidth',    cfg.width)
      set('expandtab',   not cfg.tabs)
    end)

    -- strip trailing whitespace on save (skip markdown, where it can matter)
    vis.events.subscribe(vis.events.FILE_SAVE_PRE, function(file, path)
      if path and path:match("%.md$") then return true end
      for i = 1, #file.lines do
        local line = file.lines[i]
        local stripped = line:gsub("%s+$", "")
        if stripped ~= line then file.lines[i] = stripped end
      end
      return true
    end)

    ---------------------------------------------------------------------
    -- :fmt — format the whole file with an external formatter
    ---------------------------------------------------------------------
    local formatters = {
      nix    = 'nixfmt',
      lua    = 'stylua -',
      go     = 'goimports',
      rust   = 'rustfmt --edition 2021',
      ansi_c = 'clang-format',
      cpp    = 'clang-format',
    }

    vis:command_register('fmt', function(argv, force, win, selection, range)
      local cmd = formatters[win.syntax]
      if not cmd then
        vis:info('no formatter configured for ' .. tostring(win.syntax))
        return false
      end
      local file = win.file
      local status, out, err = vis:pipe(file, { start = 0, finish = file.size }, cmd)
      if status ~= 0 then
        vis:info('fmt failed: ' .. (err or ""):gsub("\n.*", ""))
        return false
      end
      if out and #out > 0 then
        file:delete(0, file.size)
        file:insert(0, out)
      end
      return true
    end, 'Format file with external formatter')

    ---------------------------------------------------------------------
    -- Key bindings
    ---------------------------------------------------------------------
    vis:map(vis.modes.NORMAL, '<C-p>', ':open<Enter>')  -- fuzzy file open
    vis:map(vis.modes.NORMAL, '<F5>',  ':fmt<Enter>')   -- format

    -- system clipboard
    vis:map(vis.modes.VISUAL, '<C-c>', '"+y')
    vis:map(vis.modes.NORMAL, '<C-v>', '"+p')
  '';
}
