# Rex config (init.lua)

Every `rex.action` must work in a pane on a remote host (nixos, the Air) as
well as a local one, and stay fast, safe, and cheap. A key that only works
locally, or opens noticeably slower remotely, is a bug.

## How a remote pane runs an action

- The Lua runs on the Mac's server, always. `ctx.server` names the pane's host;
  `rex.session`, `rex.block.call`, and `rex.call` go there **through the app**,
  one round trip each over Tailscale. `rex.exec`, `io`, and `os` stay on the Mac.
- A floating pane (`new_layer`) runs on the pane's host. It can't see Mac
  files or Mac paths: pass data as arguments, not temp files.
- That host has no `/bin/bash` (NixOS) and a different PATH. Start scripts with
  `/bin/sh` plus `SH_PATH`; get bash through `exec bash`.
- `ctx.client_id` is the Mac server's ID for the app; every other server knows
  the app by another ID. Use `app_client(ctx)` (the app's label) for `rex -C`,
  also from a local pane whenever the command may go to another machine.
- `rex.client.queue("session.select", …)` looks the session up on the Mac's
  server, so it fails for a remote pane's session ("Go to Session could not be
  completed"). Select through the session's own host (`show_tab`).
- A remote host's rex has no host list. To reach the other machines from a
  float, pass their Tailscale endpoints in from `machine_list()` and use
  `rex -S URL`.
- The actions defined here exist only on the Mac's server. A floating script
  on another host can't `rex do <action>`: do the work with plain rex CLI
  commands there.
- A key's `rex.exec` gets neither `REX_BIN_DIR` nor `HOME`; `rex do` does, so
  a `rex do` test won't catch that.

## Performance and cost

- Count remote round trips. A loop of `rex.block.call` per tab or pane from
  the action is a loop of Tailscale round trips. Move bulk reads into the
  floating pane (`rex do -e` there runs against its local server), as
  `tab_jump` does with `TAB_ROWS`.
- `run` must return at once; never wait on user input inside it.
- A fresh `rex -S` costs a TLS handshake, 100–300 ms. When a float lists
  something and then acts on the pick, keep one `rex do -e` per machine open
  and send the pick over it, as `tab_jump` does (~60 ms instead of ~200).
- In `sh`, a background job's stdin is `/dev/null` unless redirected, and it
  inherits every open fd: a helper holding a FIFO's write end never sees EOF.

## Safety and verification

- Keep probes read-only (`rex window list --json`, `client inspect`), and test
  shell snippets on nixos with `env -i HOME=$HOME USER=$USER /bin/sh`, which is
  close to what a floating pane starts with.
- A new float starts at 80x24 and is resized to its bounds only while the app
  shows it. A test float in a session nobody is looking at stays 80x24.
- To test a floating script on another host without touching live panes, make
  a throwaway session there (`rex -S nixos new test -- …`), float the script
  over it from a `rex -S nixos do` script, then `rex -S nixos kill` it.
- After an edit: `rex config check`, `rex config reload`. When a key fails,
  `rex server logs | grep 'client.action'` has the Lua error.
- Before calling it done, ask the user to press the key in a remote pane;
  nothing here can fake the app-relayed key path.
