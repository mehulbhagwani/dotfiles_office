# One entry per Mac. This is the only file that names a machine.
#
# - The attribute name (e.g. `rac`) is the flake host: ./rebuild.sh <name>.
# - `user` is the macOS short name (the folder under /Users), not the Computer Name.
# - `computerName` is matched against `scutil --get ComputerName` when the
#   user alone does not identify the Mac.
# - `extraCasks` are Homebrew apps installed on that Mac only.
{
  rac = {
    user = "rac";
    computerName = "Rac";
    description = "Office MacBook Pro";
    extraCasks = [
      "adobe-creative-cloud"
      "blip"
      "chatgpt"
      "logi-options+"
      "spotify"
      "synology-drive"
      "tailscale-app"
      "vorssaint"
    ];
  };
  mehul-mac = {
    user = "mehul";
    computerName = "Mehul-Mac";
    description = "Personal Mac (Computer Name Mehul-Mac)";
    extraCasks = [ ];
  };
  mini-tech-s-mac-mini = {
    user = "tech";
    computerName = "Mini_Tech’s Mac mini";
    description = "Tech Mac mini (replaces the office MacBook Pro)";
    extraCasks = [
      "adobe-creative-cloud"
      "blip"
      "chatgpt"
      "logi-options+"
      "spotify"
      "synology-drive"
      "tailscale-app"
      "vorssaint"
    ];
  };
}
