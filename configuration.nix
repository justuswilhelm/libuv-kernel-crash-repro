{ config, lib, pkgs, modulesPath, ... }:
let
  debugNodejs = (self: super: {
    # This is really slow
    nodejs_22 = super.nodejs_22.overrideAttrs {
      # https://github.com/nodejs/node/blob/main/BUILDING.md#building-a-debug-build
      configureFlags = (super.configureFlags or [ ]) ++ [
        "--debug"
      ];
      preInstall = ''
        cp -a -f out/Debug/node out/Release/node || exit 1
      '';
    };
  });
  # https://www.earth.li/~noodles/blog/2022/04/resizing-consoles-automatically.html
  fix-stty-size = pkgs.writeShellApplication {
    name = "fix-stty-size";
    text = ''
      echo -ne '\e[s\e[5000;5000H'
      declare -a pos
      IFS='[;' read -p $'\e[6n' -d R -a pos -rs
      echo -ne '\e[u'

      # cols / rows
      echo "Setting stty to size: ''${pos[2]} x ''${pos[1]}"

      stty cols "''${pos[2]}" rows "''${pos[1]}"

      export TERM=xterm-256color
    '';
  };
  reproducer = pkgs.writeShellApplication {
    name = "reproducer";
    text = ''
      tmux new-session -c "$HOME" -d -s npm-ci
      tmux send-keys -t npm-ci "while true; do npm ci; done" C-m

      tmux split-window -t npm-ci
      tmux send-keys -t npm-ci "watch -d 'ps -p \$(pidof \"npm ci\") u'" C-m
      tmux split-window -t npm-ci
      tmux send-keys -t npm-ci "kill -9 \$(pidof \"npm ci\") # run when process crashes"
      tmux attach-session -t npm-ci
    '';
  };
in
{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  nixpkgs.overlays = [
    # debugNodejs
  ];

  # QEMU settings for VM
  virtualisation.cores = 4;
  virtualisation.graphics = false;
  # No need to allocate disk space
  virtualisation.diskImage = null;
  environment.etc."crash/package.json".source = ./package.json;
  environment.etc."crash/package-lock.json".source = ./package-lock.json;

  environment.systemPackages = [
    # Environment
    pkgs.tmux
    fix-stty-size
    reproducer

    # Also crashes with pkgs.nodejs_20
    pkgs.nodejs_22

    # Debug symbols
    pkgs.libuv.debug

    # Debug helpers
    pkgs.strace
    pkgs.ltrace
    pkgs.gdb
  ];
  programs.bash.loginShellInit = ''
    cp /etc/crash/* $HOME
    if [ "$(tty)" = "/dev/tty1" ] || [ "$(tty)" = "/dev/ttyS0" ]; then
      fix-stty-size
    fi
  '';
  users.motd = ''
    libuv uninterruptible process crash reproduction QEMU environment

    This environment has been built to help figure out why libuv causes issues
    with uninterruptible processes. Source repository:

    https://github.com/justuswilhelm/libuv-kernel-crash-repro

    More information:

    https://github.com/libuv/libuv/issues/4598

    Commands available:

    Fix serializer console size with the `fix-stty-size` command.
    Reproduce bug using the `reproducer` command.
  '';
  services.getty.autologinUser = "root";

  system.stateVersion = "23.11"; # Did you read the comment?
}

