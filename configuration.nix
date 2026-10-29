{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = true;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
  };
  nix-homebrew = {
    autoMigrate = true;
    enable = true;
    inherit user;
  };
  homebrew = {
    enable = true;
    # uninstall drops packages not in this file; zap also deletes their app data.
    onActivation.cleanup = "uninstall";
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    brews = [
      "age"
      "atuin"
      "bat"
      "direnv"
      "exiftool"
      "eza"
      "fd"
      "ffmpeg"
      "fzf"
      "gh"
      "git"
      "handbrake"
      "git-delta"
      "git-lfs"
      "herdr"
      "hyperfine"
      "imagemagick"
      "jq"
      "mise"
      "node"
      "opencode"
      "pi-coding-agent"
      "repomix"
      "ripgrep"
      "sops"
      "tmux"
      "tree"
      "uv"
      "watchexec"
      "wget"
      "yt-dlp"
      "zoxide"
    ];
    casks = [
      "brave-browser"
      "claude-code@latest"
      "codex"
      "ghostty"
      "hyperwhisper"
      "localsend"
      "kunchenguid/tap/pi-launcher"
      "openlogi"
      "orbstack"
      "obsidian"
      "visual-studio-code"
      "wezterm"
    ];
  };
}
