# Note synchronization

The NixOS Home Manager adapter installs `note-sync.timer`, which runs every
30 minutes while the user manager is running. Missed runs are caught up at
the next login. The repository is `~/Documents/noarmal-note-seq`.

`note-sync.sh` commits local changes (including new files and deletions), pulls
with rebase, and pushes to the current branch's configured upstream. Git's
ignore rules apply. Overlapping runs are skipped. An unfinished merge or
rebase stops synchronization until it is resolved manually. SSH must work
without interactive password or host-key prompts.

```sh
systemctl --user list-timers note-sync.timer
journalctl --user -u note-sync.service -n 50
systemctl --user start note-sync.service # synchronize immediately
systemctl --user stop note-sync.timer   # pause scheduled synchronization
```

The older `sync-note.sh.template` is retained for reference; it is not used by
the NixOS timer.
