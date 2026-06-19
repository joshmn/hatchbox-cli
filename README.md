# hatchbox

A command line for [Hatchbox](https://hatchbox.io) that works on the app you're standing in. One file, standard library only.

## Install

```bash
cp hatchbox.rb ~/bin/hatchbox
chmod +x ~/bin/hatchbox
```

## Setup

Make an API token at https://hatchbox.io/api_tokens, then from inside the repo:

```bash
hatchbox setup
```

It asks for the token, saves it to `~/.hatchbox`, lets you pick an app and writes a `.hatchbox` next to the repo:

```
13673-fpd:production
20001-fpd-qa:qa
default = production
```

Pick an environment with `-e qa`.

## Using it

```bash
hatchbox deploy --watch
hatchbox status
hatchbox ps
hatchbox ps:restart sidekiq
hatchbox logs --ps sidekiq -t
hatchbox releases
hatchbox config:set FOO=bar
hatchbox run "rails db:migrate"
hatchbox ssh
hatchbox psql
```

`hatchbox --help` has the rest.
