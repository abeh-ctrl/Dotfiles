{ pkgs, ... }:
{
  imports = [ ./vis.nix ];   

  home.username = "abeh";
  home.homeDirectory = "/home/abeh";
  home.stateVersion = "26.05";   

  programs.home-manager.enable = true;
}
