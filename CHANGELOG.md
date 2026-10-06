## [Unreleased]

- `~/.hatchbox` is JSON now and holds every repo's remotes, default remote and SSH overrides, keyed by the repo's path. Per-repo `.hatchbox` files are no longer read or written, so run `hatchbox setup` again. An old-format `~/.hatchbox` isn't migrated; delete it and run `hatchbox login`.
- One token per machine. Per-remote tokens are gone.
- `HATCHBOX_ENV` is now `HATCHBOX_REMOTE`, and it's in `hatchbox help`. `HATCHBOX_ASSUME_YES` is gone.
- `deploy --status`, `deploy status`, `deploy --watch` and `deploy --no-follow` are gone. Use `status` and `deploy --no-wait`.
- `run -x/--exit-code` is gone. The exit code always passes through.
- `pg:backups:info` follows a backup that's still running instead of printing part of it and exiting 1.
- `ps:create --server` and `ps:update --server` take a server's id or a unique part of its name, and check the id against the cluster.
- `apps:update --git-provider` errors read the same as `apps:create`'s.
- `mysql:cli -c=SQL` works the same as `pg:psql -c=SQL`.
- `setup` (`git:remote`) puts the app it thinks matches this repo at the top of the list, and takes a number, id or name. Enter takes the guess.
- `setup` checks a newly entered token against the API before saving it, the same way `login` does.
- Dynos are gone. `ps` and `ps:info` show which servers each process runs on.
- Log lines are labeled `process@server`.
- `-d/--dyno` is removed. `run`, `run:detached`, `ps:exec`, `ps:forward`, `ps:socks` and `ps:copy` take `-s/--server` instead, and `logs` takes `--server`.
- `logs --run ID` reads back `run:detached` output.
- Commands declare their arguments, so stray arguments are an error everywhere and the messages read the same across commands.
- `HATCHBOX_API_BASE` is gone. The API lives at https://hatchbox.io/api/v1.
- `pg:info` labels the database's name `Database` instead of `Add-on`.
- Help for a command that is also a topic, like `run` or `ps`, shows its full help and examples.
- Commands that use SSH are marked `(ssh)`, and their help says so.
- `servers:reboot`, `servers:provision`, `servers:roles:*` and `firewall:add`/`firewall:remove` with `--cluster` no longer need an app. They used to send the change and then exit 1 with "No app specified."
- `run`, `run:detached` and `cron:add` pass flags like `-al` and `-rt` through to the command once it has started, instead of reading them as `-a l` or `-r t`. `-a APP` and `-r REMOTE` with a space still pick the app.

## [2.0.0] - 2026-10-04

- Packaged the hatchbox script as a gem. Same commands, flags and output.
- Commands that only need a server (`run`, `ps:exec`, `ps:forward`, `ps:socks`, `ps:copy`, `logs -d run.ID`) no longer fetch the app's processes first.
