{ config, pkgs, lib, ... }:

{
  # ─── Thunar + plugins ──────────────────────────────────────────────
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
      thunar-media-tags-plugin
    ];
  };

  # ─── Supporting services ───────────────────────────────────────────
  services.gvfs.enable = true;     # trash, network mounts, MTP devices
  services.tumbler.enable = true;  # thumbnail generation
  services.udisks2.enable = true;  # removable media handling
  security.polkit.enable = true;   # privileged mount actions without a root prompt every time

  environment.systemPackages = with pkgs; [
    xarchiver           # archive extraction/compression backend for thunar-archive-plugin

    # ─── Catppuccin Mocha theming ────────────────────────────────────
    catppuccin-gtk
    catppuccin-cursors
    papirus-icon-theme  # base icon set; pairs with Catppuccin folder color overlays
  ];
}
