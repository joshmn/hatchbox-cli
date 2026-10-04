# hatchbox

A heroku-style command line for [Hatchbox](https://hatchbox.io). If your fingers already know `heroku ps:restart` and `heroku pg:psql`, they know this too.

It talks to the Hatchbox API for everything the API covers (apps, processes, config vars, domains, cron, databases, backups, servers, firewall rules) and goes over SSH for the things it doesn't, like logs, `run` and `psql`. No runtime dependencies, just the standard library.

## Installation

```bash
gem install hatchbox
```

## Logging in

Hatchbox has no password login for its API, so you need a token. Make one at https://hatchbox.io/api_tokens and then:

```bash
hatchbox login
```

That saves it to `~/.hatchbox`. `HATCHBOX_API_TOKEN` wins over the file when it's set, which is handy for CI.

## Pointing a repo at an app

From inside the repo:

```bash
hatchbox git:remote
```

It looks for the app whose repo matches one of your git remotes and writes a `.hatchbox` file at the root of the repo. With more than one environment it ends up looking like this:

```
13673-fpd:production
20001-fpd-qa:qa
default = production
```

Only the leading number matters to Hatchbox; the rest is there so you can tell which app it is. Pick one with `-r qa`, or skip the file entirely with `-a fpd`.

The same file takes per-remote SSH overrides for when the defaults (the `deploy` user, the server's public IP, port 22) are wrong:

```
ssh_user:production = deploy
ssh_host:production = 203.0.113.10
ssh_port:production = 22
app_dir:production = /home/deploy/fpd/current
```

## Using it

```bash
hatchbox apps
hatchbox deploy
hatchbox logs --tail
hatchbox run rails console
hatchbox config:set RAILS_ENV=production
hatchbox ps:restart sidekiq
hatchbox pg:psql
hatchbox releases:rollback
```

`hatchbox help` lists everything and `hatchbox help COMMAND` has the details. `postgresql:` works anywhere `pg:` does.

A few things behave differently from heroku because Hatchbox is a different animal. Config var values are write-only (the API never returns them), so `config` lists names. `ps:stop` keeps a process off through deploys until `ps:start` turns it back on. `rollback` redeploys an older commit, since Hatchbox has no releases to restore. `pg:psql` and `mysql:cli` sessions are read only unless you pass `--dangerous`.

## Environment

| Variable | What it does |
| --- | --- |
| `HATCHBOX_API_TOKEN` | overrides the token in `~/.hatchbox` |
| `HATCHBOX_APP` | app to use when `-a` and `-r` are left off |
| `HATCHBOX_SSH_OPTIONS` | extra ssh flags, like `-i ~/.ssh/hatchbox` |
| `HATCHBOX_API_BASE` | defaults to `https://hatchbox.io/api/v1` |
| `NO_COLOR` | turns colors off |

## Development

```bash
bin/setup
bundle exec exe/hatchbox help
```

`bin/console` gives you an IRB session with the gem loaded. To release, bump `lib/hatchbox/version.rb` and run `bundle exec rake release`.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
