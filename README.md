# hatchbox

A heroku-style command line for [Hatchbox](https://hatchbox.io). One file, standard library only.

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

It writes a `.hatchbox` at the root of the repo:

```
13673-fpd:production
20001-fpd-qa:qa
default = production
```

Pick an environment with `-e qa`. `hatchbox remotes` lists them.

## Using it

```bash
hatchbox apps
hatchbox apps:info
hatchbox deploy --watch
hatchbox ps:restart sidekiq
hatchbox logs --ps sidekiq -t
hatchbox config:set FOO=bar
hatchbox run "rails db:migrate"
hatchbox ps:exec
hatchbox pg:psql
```

`hatchbox --help` has the rest.
