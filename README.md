# hatchbox

A heroku-style command line for [Hatchbox](https://hatchbox.io). If your fingers remember how to use the `heroku` CLI, you'll feel at home.

It uses the Hatchbox API for everything it can, and ties into SSH for things it can't. 
It talks to the Hatchbox API for everything the API covers (apps, processes, config vars, domains, cron, databases, backups, servers, firewall rules) and goes over SSH for the things it doesn't, like logs, `run` and `psql`.

## Installation

```bash
gem install hatchbox
```

Cool.

## Logging in

Hatchbox has no password login for its API, so you need a token. Make one at https://hatchbox.io/api_tokens and then:

```bash
hatchbox login
```

## Pointing a repo at an app

From inside the repo:

```bash
hatchbox setup
```

will pull all your apps and guess which one matches your git remotes. The guess goes at the top of the list, so hit enter to take it, or type a number, id or name to pick something else.

Otherwise,

```bash
hatchbox git:remote
```

## Where things live

Everything goes in `~/.hatchbox`, which is JSON: your token, plus one entry per repo (keyed by the repo's path) with its remotes, which one is the default, and any SSH overrides. Nothing gets written into the repo itself, so there's nothing to gitignore.

```json
{
  "token": "...",
  "projects": {
    "/Users/you/code/fpd": {
      "remotes": { "production": "13673-fpd", "qa": "20001-fpd-qa" },
      "default": "production",
      "ssh": {
        "production": { "user": "deploy", "host": "203.0.113.10", "port": 22, "app_dir": "/home/deploy/fpd/current" }
      }
    }
  }
}
```

The `ssh` block is only for when Hatchbox's defaults (the deploy user, the server's public IP) don't work for you. Commands marked `(ssh)` in `hatchbox help` are the ones that use it.

If you have an older `~/.hatchbox`, your token carries over the first time something writes to it. Old per-repo `.hatchbox` files are ignored now, so run `hatchbox setup` again in those repos.

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

feels great, don't it?

## Kind of important differences 


A few things behave differently from heroku because Hatchbox is different.

* Config var values are write-only (the API never returns them), so `config` lists names. 
* `ps:stop` keeps a process off through deploys until `ps:start` turns it back on. 
* `rollback` redeploys an older commit, since Hatchbox has no releases to restore. 
* `pg:psql` and `mysql:cli` sessions are read only unless you pass `--dangerous`.

## Environment

| Variable | What it does |
| --- | --- |
| `HATCHBOX_API_TOKEN` | overrides the token in `~/.hatchbox` |
| `HATCHBOX_APP` | app to use when `-a` and `-r` are left off |
| `HATCHBOX_SSH_OPTIONS` | extra ssh flags, like `-i ~/.ssh/hatchbox` |
| `NO_COLOR` | turns colors off |

## Contributing

Include your favorite recipe in your hand-rolled PR; I'll ignore it otherwise, sorry.

## Development

MIT. See [LICENSE.txt](LICENSE.txt).
