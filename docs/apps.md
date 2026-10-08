# hatchbox apps

manage apps (create, destroy, info, rename, open)

* [`hatchbox apps`](#hatchbox-apps)
* [`hatchbox apps:create`](#hatchbox-appscreate)
* [`hatchbox apps:destroy`](#hatchbox-appsdestroy)
* [`hatchbox apps:info`](#hatchbox-appsinfo)
* [`hatchbox apps:open`](#hatchbox-appsopen)
* [`hatchbox apps:rename`](#hatchbox-appsrename)
* [`hatchbox apps:update`](#hatchbox-appsupdate)

## hatchbox apps

List your apps.

```
Usage: hatchbox apps

Flags:
  -t, --team TEAM  only the apps on this account, by name or id
      --json       output in json format
```

Aliases: `apps:list`, `list`

Examples:

```
$ hatchbox apps
=== My Team Apps
fpd (netcup)
stox (purevoltage-ny)
```

## hatchbox apps:create

Create a new app on a cluster.

```
Usage: hatchbox apps:create NAME

Flags:
  -c, --cluster CLUSTER        cluster to create the app on, by name or id
  -t, --team TEAM              account the cluster belongs to, by name or id
      --repo REPO              repository to deploy, e.g. myuser/my-app
  -b, --branch BRANCH          branch to deploy, main unless you say otherwise
      --git-provider PROVIDER  connected git account to deploy from, by name, provider:name or id
      --no-remote              do not save the app as a remote for this repo
```

Creates the app with auto-deploy off. Inside a git repo, the app is saved in ~/.hatchbox as a remote for that repo, named with -r, or production if you leave -r off.

Aliases: `create`

Examples:

```
$ hatchbox apps:create my-app --cluster netcup --repo myuser/my-app --git-provider joshmn
Creating my-app on netcup... done
set remote production to 14001-my-app for ~/code/my-app in ~/.hatchbox
```

## hatchbox apps:destroy

Permanently destroy an app.

```
Usage: hatchbox apps:destroy [APP]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --confirm APP    the app's name, to skip the prompt
      --no-wait        return once Hatchbox has queued it, without waiting for it to finish
```

Any remote this repo has pointing at the app is removed from ~/.hatchbox.

Aliases: `destroy`

## hatchbox apps:info

Show detailed app information.

```
Usage: hatchbox apps:info [APP]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -x, --extended       show the deploy scripts, the Caddyfile and the DNS settings too
  -s, --shell          output more shell friendly key/value pairs
      --json           output in json format
```

Aliases: `info`

## hatchbox apps:open

Open the app in a web browser.

```
Usage: hatchbox apps:open [PATH]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

Opens the app's first domain over https. Wildcard domains are skipped.

Aliases: `open`

## hatchbox apps:rename

Rename an app.

```
Usage: hatchbox apps:rename NEWNAME

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --confirm APP    the app's current name, to skip the prompt
      --no-wait        return once Hatchbox has queued it, without waiting for it to finish
```

Any remote this repo has pointing at the app is updated to the new name.

Aliases: `rename`

## hatchbox apps:update

Change an app's repo, branch, deploy scripts, Caddy or DNS settings.

```
Usage: hatchbox apps:update

Flags:
  -a, --app APP                      app to run command against
  -r, --remote REMOTE                remote saved for this repo in ~/.hatchbox to run command against
  -b, --branch BRANCH                branch to deploy
      --repo REPO                    repository to deploy, e.g. myuser/my-app
      --git-provider PROVIDER        connected git account to deploy from, by name, provider:name or id
      --pre-build-script SCRIPT      script run before the build, or @FILE to read it from a file
      --build-script SCRIPT          build script, or @FILE
      --post-build-script SCRIPT     script run after the build, or @FILE
      --post-deploy-script SCRIPT    script run after the deploy, or @FILE
      --failed-deploy-script SCRIPT  script run once when a deploy fails, or @FILE
      --health-check PATH            relative path for Caddy to health check, e.g. /up
      --caddyfile FILE               Caddyfile to apply, or - to read it from stdin
      --dns-provider PROVIDER        DNS provider for certificates
      --dns-api-user USER            DNS API user
      --dns-access-token TOKEN       DNS access token
```
