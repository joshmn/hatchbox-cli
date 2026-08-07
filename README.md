# hatchbox

A heroku-style command line for [Hatchbox](https://hatchbox.io). If your fingers already know `heroku ps:restart` and `heroku pg:psql`, they know this too. One file, standard library only.

## Install

```bash
cp hatchbox.rb ~/bin/hatchbox
chmod +x ~/bin/hatchbox
```

## Logging in

Make an API token at https://hatchbox.io/api_tokens, then:

```bash
hatchbox login
```

That saves it to `~/.hatchbox`. `HATCHBOX_API_TOKEN` wins over the file when it's set.

## Pointing a repo at an app

From inside the repo:

```bash
hatchbox git:remote
```

It looks for the app whose repo matches one of your git remotes and writes a `.hatchbox` at the root of the repo:

```
13673-fpd:production
20001-fpd-qa:qa
default = production
```

Pick one with `-r qa`, or skip the file entirely with `-a fpd`.

The same file takes per-remote SSH overrides:

```
ssh_user:production = deploy
ssh_host:production = 203.0.113.10
ssh_port:production = 22
app_dir:production = /home/deploy/fpd/current
```

## Using it

```bash
hatchbox apps
hatchbox deploy --watch
hatchbox ps
hatchbox ps:restart sidekiq
hatchbox ps:exec -d sidekiq.2
hatchbox ps:forward 9090
hatchbox logs -p sidekiq --tail
hatchbox run --env FOO=bar rails console
hatchbox config:set RAILS_ENV=production
hatchbox domains:add www.example.com
hatchbox pg:psql
```

`hatchbox help` lists everything.
