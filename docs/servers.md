# hatchbox servers

manage servers, their roles and reboots

* [`hatchbox servers`](#hatchbox-servers)
* [`hatchbox servers:activity`](#hatchbox-serversactivity)
* [`hatchbox servers:info`](#hatchbox-serversinfo)
* [`hatchbox servers:provision`](#hatchbox-serversprovision)
* [`hatchbox servers:reboot`](#hatchbox-serversreboot)
* [`hatchbox servers:roles`](#hatchbox-serversroles)
* [`hatchbox servers:roles:add`](#hatchbox-serversrolesadd)
* [`hatchbox servers:roles:remove`](#hatchbox-serversrolesremove)
* [`hatchbox servers:roles:set`](#hatchbox-serversrolesset)

## hatchbox servers

List the servers in the app's cluster.

```
Usage: hatchbox servers

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER  the cluster, by name or id, instead of the app's
      --json             output in json format
```

Aliases: `servers:list`

## hatchbox servers:activity

List what Hatchbox has done to a server.

```
Usage: hatchbox servers:activity SERVER

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER  the cluster, by name or id, instead of the app's
  -n, --num NUM          number of entries
      --all              include the per-server output of app deploys
      --json             output in json format
```

## hatchbox servers:info

Show one server.

```
Usage: hatchbox servers:info SERVER

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER  the cluster, by name or id, instead of the app's
      --json             output in json format
```

## hatchbox servers:provision

Rerun provisioning on a server, the dashboard's Update button.

```
Usage: hatchbox servers:provision SERVER

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER  the cluster, by name or id, instead of the app's
      --confirm SERVER   the server's name, to skip the prompt
      --no-wait          return once Hatchbox has queued it, without waiting for it to finish
```

## hatchbox servers:reboot

Reboot a server.

```
Usage: hatchbox servers:reboot SERVER

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER  the cluster, by name or id, instead of the app's
      --confirm SERVER   the server's name, to skip the prompt
      --no-wait          return once Hatchbox has queued it, without waiting for it to finish
```

## hatchbox servers:roles

List a server's roles.

```
Usage: hatchbox servers:roles SERVER

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER  the cluster, by name or id, instead of the app's
```

## hatchbox servers:roles:add

Give a server more roles.

```
Usage: hatchbox servers:roles:add SERVER ROLE [ROLE ...]

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER  the cluster, by name or id, instead of the app's
      --confirm SERVER   the server's name, to go ahead when it destroys data
      --no-wait          return once Hatchbox has queued it, without waiting for it to finish
```

hatchbox help servers:roles:set lists the roles.

## hatchbox servers:roles:remove

Take roles off a server.

```
Usage: hatchbox servers:roles:remove SERVER ROLE [ROLE ...]

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER  the cluster, by name or id, instead of the app's
      --confirm SERVER   the server's name, to go ahead when it destroys data
      --no-wait          return once Hatchbox has queued it, without waiting for it to finish
```

hatchbox help servers:roles:set lists the roles.

## hatchbox servers:roles:set

Replace a server's roles with the ones given.

```
Usage: hatchbox servers:roles:set SERVER ROLE [ROLE ...]

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER  the cluster, by name or id, instead of the app's
      --confirm SERVER   the server's name, to go ahead when it destroys data
      --no-wait          return once Hatchbox has queued it, without waiting for it to finish
```

Roles:   app, web, worker, cron, load_balancer   postgresql, mysql, redis, memcached, elasticsearch

A change that destroys data needs the server's name typed back.
