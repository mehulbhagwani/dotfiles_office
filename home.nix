{ config, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.packages = with pkgs; [
    # ripgrep, fd, fzf and jq are declared as brews in configuration.nix
    # instead: Homebrew is first on PATH, so a Nix copy here would only ever
    # be shadowed dead weight.
    lazygit
    neovim
    # the font everything renders in
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";

  # OrbStack keeps docker, compose, kubectl and orb inside its app bundle.
  # Its own installer only wires ~/.orbstack/bin once the app has been run,
  # so pointing at the bundle gives a working CLI without launching it.
  home.sessionPath = [
    "/Applications/OrbStack.app/Contents/MacOS/xbin"
    "/Applications/OrbStack.app/Contents/MacOS/bin"
  ];

  # chrome-devtools-axi drives Brave, this machine's browser, not Chrome.
  home.sessionVariables.CHROME_DEVTOOLS_AXI_EXECUTABLE_PATH =
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser";

  # The -axi command line tools are global npm packages, so neither Nix nor
  # Homebrew knows about them and a fresh machine would come up without any.
  home.activation.npmGlobals =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run ${dotfiles}/scripts/npm-globals.sh
    '';

  # Kun skills are git clones, not copies baked into this repo. A rebuild
  # fetches the declared set and links them for Claude and Pi.
  home.activation.kunSkills =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run ${dotfiles}/scripts/kun-sync.sh
    '';

  # `npm update -g` reverts the patch that teaches chrome-devtools-axi to launch
  # Brave, so re-applying it here is what keeps the setting from rotting. Runs
  # after npmGlobals so a freshly installed copy gets patched too.
  home.activation.chromeDevtoolsAxiBrave =
    config.lib.dag.entryAfter [ "npmGlobals" ] ''
      run ${dotfiles}/scripts/chrome-devtools-axi-brave.sh
    '';

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
      eval "$(direnv hook zsh)"
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude --dangerously-skip-permissions --autocompact 500000";
      co = "codex --full-auto";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  # herdr owns ~/.config/herdr at runtime (sockets, logs, session.json), so link
  # only the authored file - same reasoning as the .pi entries below.
  home.file.".config/herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr/config.toml";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  # Keep Pi's credential and runtime state local by linking only authored files and directories.
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";
  home.file.".pi/agent/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/keybindings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".pi/agent/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
