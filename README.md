# libuv + Linux 6.6 LTS uninterruptible process crash reproduction

Keywords:

- io_uring
- libuv
- Linux LTS 6.6
- NixOS


References:

- https://github.com/nodejs/node/issues/55587
- https://github.com/libuv/libuv/issues/4598
- https://lore.kernel.org/io-uring/3d913aef-8c44-4f50-9bdf-7d9051b08941@app.fastmail.com/T/#mcddcf299eb2ec40aca4bf8b938067b9682c8eb27

# Requirements

- [Nix](https://nixos.org/download/#download-nix)
- [Nix flake support](https://nixos.wiki/wiki/Flakes)
- x86_64 host that can run QEMU/KVM images

# How to reproduce

1. Start QEMU VM using the following command:

```bash
nix run .#nixosConfigurations.nixos-vm.config.system.build.vm
```

2. You are automatically logged in as root
3. A reproduction tmux contraption runs automatically with the following being
   run in the top pane inside an infinite bash loop:

```bash
npm ci
```

4. The middle pane shows the current state of `npm ci` using `watch ps`.
5. Wait for CPU activity in `npm ci` to die down and execute the following in
   the bottom pane:

```bash
# You are automatically focus on the bottom pane
# Refer to ps u PID for NODE_PROCESS_PID
kill -9 $NODE_PROCESS_PID
```

6. If `npm ci` quits successfully, it is rerun, so please wait.
7. If `npm ci` crashes, you will see the tmux pane with `watch ps u` say:

```
# Some of the values may vary
USER PID  %CPU $MEM VS2     RSS   TTY   STAT START TIME COMMAND
root $PID 4.0  0.4  1313736 71744 pts/0 Dl+  01:46 0:01 npm ci
```

8. Roughly a minute later you will see Kernel warnings being output in the
   console and on `dmesg`. Note: If you don't kill the process, an error message
   might not be shown. Please make sure you try to kill `npm ci`:

```
INFO: task iou-sqp-1031:1039 blocked for more than 122 seconds.
   Not tained 6.6.58 #1-NixOS
```

9. Try turning the machine off with `poweroff`. The systemd shutdown target
   will fail at terminating the root user's processes.
