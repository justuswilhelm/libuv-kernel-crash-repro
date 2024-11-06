{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  # QEMU settings for VM
  virtualisation.cores = 2;
  # No need to allocate disk space
  virtualisation.diskImage = null;
  environment.etc."crash/package.json".source = ./package.json;
  environment.etc."crash/package-lock.json".source = ./package-lock.json;

  environment.systemPackages = [
    pkgs.tmux
    # Also crashes with pkgs.nodejs_20
    pkgs.nodejs_22
    pkgs.libuv.debug
    pkgs.strace
    pkgs.ltrace
    pkgs.gdb
  ];
  programs.bash.loginShellInit = ''
    cp -nv /etc/crash/* $HOME
    if [ "$(tty)" = "/dev/tty1" ]; then
      tmux new-session -c "$HOME" -d -s npm-ci
      tmux send-keys -t npm-ci "while true; do npm ci; done" C-m

      tmux split-window -t npm-ci
      tmux send-keys -t npm-ci "watch -d 'ps -p \$(pidof \"npm ci\") u'" C-m
      tmux split-window -t npm-ci
      tmux send-keys -t npm-ci "kill -9 \$(pidof \"npm ci\") # run when process crashes"
      tmux attach-session -t npm-ci
    fi
  '';
  services.getty.autologinUser = "root";

  system.stateVersion = "23.11"; # Did you read the comment?
}

