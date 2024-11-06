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

# Screenshots

First some screenshots to make clear what I see on my system when a crash occurs:

![NPM killed after timing out](./npm-ci-killed.png)

![Console showing blocked task kernel INFO](./blocking-task.png)

![Detailed `dmesg` output](./dmesg-output.png)

![System refuses to power off](./power-off-fail.png)

## Debug symbols

It's possible to reproduce the bug inside gdb when running:

```bash
gdb --args node $(which npm) ci
```

![Nodejs will spend most its time in uv.io_poll](./stuck-in-uv-io-poll.png)

![After continuing and interrupting, we are still inside uv.io_poll](./still-in-uv-io-poll.png)

Here's the stack trace:

```
0x00007ffff51fb086 in epoll_pwait ()
   from /nix/store/c10zhkbp6jmyh0xc5kd123ga8yy2p4hk-glibc-2.39-52/lib/libc.so.6
(gdb) where
#0  0x00007ffff51fb086 in epoll_pwait ()
   from /nix/store/c10zhkbp6jmyh0xc5kd123ga8yy2p4hk-glibc-2.39-52/lib/libc.so.6
#1  0x00007ffff7f92140 in uv.io_poll ()
   from /nix/store/arhy8i96l81wz3zrldiwcmiax2gc2w7s-libuv-1.48.0/lib/libuv.so.1
#2  0x00007ffff7f7f910 in uv_run ()
   from /nix/store/arhy8i96l81wz3zrldiwcmiax2gc2w7s-libuv-1.48.0/lib/libuv.so.1
#3  0x0000000000d5dfdb in node::SpinEventLoopInternal(node::Environment*) ()
#4  0x0000000000ecf51b in node::NodeMainInstance::Run(node::ExitCode*, node::Environment*) ()
#5  0x0000000000ecf8fa in node::NodeMainInstance::Run() ()
#6  0x0000000000e22d7c in node::Start(int, char**) ()
#7  0x00007ffff511b10e in __libc_start_call_main ()
   from /nix/store/c10zhkbp6jmyh0xc5kd123ga8yy2p4hk-glibc-2.39-52/lib/libc.so.6
#8  0x00007ffff511b1c9 in __libc_start_main_impl ()
   from /nix/store/c10zhkbp6jmyh0xc5kd123ga8yy2p4hk-glibc-2.39-52/lib/libc.so.6
#9  0x0000000000d5bd95 in _start ()
```

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
