## [Unreleased]

- `~/.hatchbox` is JSON now and holds every repo's remotes, default remote and SSH overrides, keyed by the repo's path. Per-repo `.hatchbox` files are no longer read or written, so run `hatchbox setup` again. An old `~/.hatchbox` keeps its tokens.
- `setup` (`git:remote`) puts the app it thinks matches this repo at the top of the list, and takes a number, id or name. Enter takes the guess.
- `setup` checks a newly entered token against the API before saving it, the same way `login` does.
- Dynos are gone. `ps` and `ps:info` list the servers each process runs on, log lines are labeled `process@server`, `-d/--dyno` is removed in favor of `-s/--server`, and `logs --run ID` reads back `run:detached` output.
- Commands declare their arguments, so stray arguments are an error everywhere and the messages read the same across commands.
- `HATCHBOX_API_BASE` is gone. The API lives at https://hatchbox.io/api/v1.
- `pg:info` labels the database's name `Database` instead of `Add-on`.
- Help for a command that is also a topic, like `run` or `ps`, shows its full help and examples. Commands that use SSH are marked `(ssh)` and say so in their help.
- `servers:reboot`, `servers:provision`, `servers:roles:*` and `firewall:add`/`firewall:remove` with `--cluster` work outside an app folder. They used to send the change and then exit 1 with "No app specified."
- `run`, `run:detached` and `cron:add` pass flags like `-al` and `-rt` through to the command once it has started, instead of reading them as `-a l` or `-r t`. `-a APP` and `-r REMOTE` with a space still pick the app.

## [2.0.0] - 2026-10-04

- Packaged the hatchbox script as a gem. Same commands, flags and output.
- Commands that only need a server (run, ps:exec, ps:forward, ps:socks, ps:copy, logs -d run.ID) no longer fetch the app's processes first.
