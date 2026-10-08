# hatchbox git

save apps as remotes for this repo, list git providers

* [`hatchbox git:providers`](#hatchbox-gitproviders)
* [`hatchbox git:remote`](#hatchbox-gitremote)

## hatchbox git:providers

List the connected git accounts apps can deploy from.

```
Usage: hatchbox git:providers

Flags:
  -t, --team TEAM  only this account, by name or id
      --json       output in json format
```

## hatchbox git:remote

Save an app as a remote for this repo.

```
Usage: hatchbox git:remote [FILTER]

Flags:
      --as REMOTE  the remote name, same as -r
```

Picks an app off your accounts, or takes the one named with -a, and saves it in ~/.hatchbox for the repo you are in (or this folder, outside a repo) under the remote named with -r. Without -a it guesses from this repo's git remotes and puts that app at the top of the list, so enter takes it; otherwise pick one by number, id or name. FILTER narrows the list. Without a terminal, it only goes ahead when exactly one app in the list deploys this repo. Without -r it asks, suggesting the end of the app's name when that looks like an environment (qa in fpd-qa), and production otherwise.

~/.hatchbox is JSON. Each project is keyed by its repo's path and holds its remotes, an optional default, and optional SSH settings per remote for the commands that connect over SSH:

```
"projects": {
  "/Users/you/code/fpd": {
    "remotes": { "production": "13673-fpd", "qa": "20001-fpd-qa" },
    "default": "production",
    "ssh": {
      "production": {
        "user": "deploy", "host": "203.0.113.10", "port": 22,
        "app_dir": "/home/deploy/fpd/current"
      }
    }
  }
}
```

Only the leading number of each app is read; the rest tells you which app it is.

Aliases: `setup`

Examples:

```
$ hatchbox git:remote -a fpd -r production
set remote production to 13673-fpd for ~/code/fpd in ~/.hatchbox
```
