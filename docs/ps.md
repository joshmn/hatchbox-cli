# hatchbox ps

manage processes (restart, stop, start, exec)

* [`hatchbox ps`](#hatchbox-ps)
* [`hatchbox ps:copy`](#hatchbox-pscopy)
* [`hatchbox ps:create`](#hatchbox-pscreate)
* [`hatchbox ps:destroy`](#hatchbox-psdestroy)
* [`hatchbox ps:exec`](#hatchbox-psexec)
* [`hatchbox ps:forward`](#hatchbox-psforward)
* [`hatchbox ps:info`](#hatchbox-psinfo)
* [`hatchbox ps:restart`](#hatchbox-psrestart)
* [`hatchbox ps:socks`](#hatchbox-pssocks)
* [`hatchbox ps:start`](#hatchbox-psstart)
* [`hatchbox ps:stop`](#hatchbox-psstop)
* [`hatchbox ps:update`](#hatchbox-psupdate)

## hatchbox ps

List processes for an app.

```
Usage: hatchbox ps [TYPE [TYPE ...]]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --json           output in json format
```

Hatchbox's API knows whether a process is enabled, not whether it is up right now; hatchbox logs and hatchbox ps:exec reach the servers for that.

Examples:

```
$ hatchbox ps
=== server (role web): bin/rails server (1)
web-1  enabled  203.0.113.10
```

## hatchbox ps:copy

Copy a file off one of the app's servers (ssh).

```
Usage: hatchbox ps:copy FILE

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -o, --output FILE    where to write it, the file's own name unless you say otherwise
  -s, --server SERVER  the server, by name, id or role
```

A relative FILE is read from the app's current release.

Uses SSH. It connects as the deploy user to one or more of the app's servers, so your key has to be on them (and should be had you provision your server through Hatchbox. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

Examples:

```
$ hatchbox ps:copy log/production.log
Copying log/production.log to production.log... done
```

## hatchbox ps:create

Add a process to the app.

```
Usage: hatchbox ps:create NAME --start COMMAND (--roles LIST | --server SERVER)

Flags:
  -a, --app APP                    app to run command against
  -r, --remote REMOTE              remote saved for this repo in ~/.hatchbox to run command against
      --name NAME                  process name, letters, numbers, hyphens and underscores
      --start COMMAND              the command that runs
      --stop COMMAND               command systemd runs to stop it
      --reload COMMAND             command systemd runs to reload it
      --roles LIST                 comma-separated roles
      --server SERVER              one server to run on instead of roles, by name or id
      --systemd-type TYPE          simple or oneshot
      --[no-]socket                systemd socket activation, at most one process per app
      --[no-]restart-on-deploy     restart it on every deploy, which is the default
      --[no-]appsignal             run it under appsignal-wrap
      --appsignal-options OPTIONS  extra flags for appsignal-wrap
      --no-wait                    return once Hatchbox has queued it, without waiting for it to finish
```

Examples:

```
$ hatchbox ps:create worker --start 'bundle exec sidekiq' --roles worker
Creating worker on fpd... done
```

## hatchbox ps:destroy

Destroy a process.

```
Usage: hatchbox ps:destroy TYPE

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --confirm TYPE   the process name, to skip the prompt
      --no-wait        return once Hatchbox has queued it, without waiting for it to finish
```

## hatchbox ps:exec

Open an SSH session on one of the app's servers (ssh).

```
Usage: hatchbox ps:exec [COMMAND]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -s, --server SERVER  the server, by name, id or role
```

Lands in the app's current release, /home/deploy/APP/current, and falls back to the home directory when nothing is deployed yet. COMMAND runs there and comes back; quote it as one argument.

Uses SSH. It connects as the deploy user to one or more of the app's servers, so your key has to be on them (and should be had you provision your server through Hatchbox. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

Aliases: `ssh`

## hatchbox ps:forward

Forward traffic on a local port to a server (ssh).

```
Usage: hatchbox ps:forward PORT[,PORT...]

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
  -p, --local-port PORT  local port to use, comma-separated to match PORT
  -s, --server SERVER    the server, by name, id or role
```

Uses SSH. It connects as the deploy user to one or more of the app's servers, so your key has to be on them (and should be had you provision your server through Hatchbox. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

Examples:

```
$ hatchbox ps:forward 9090
SSH tunnel established.
Forwarding localhost:9090 to web-1:9090
Use Ctrl+C to stop port forwarding
```

## hatchbox ps:info

Show one process.

```
Usage: hatchbox ps:info TYPE

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --json           output in json format
```

## hatchbox ps:restart

Restart every process, or one process type.

```
Usage: hatchbox ps:restart [TYPE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --no-wait        return once Hatchbox has queued it, without waiting for it to finish
```

Aliases: `restart`

## hatchbox ps:socks

Launch a SOCKS proxy into one of the app's servers (ssh).

```
Usage: hatchbox ps:socks

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -p, --port PORT      local port for the proxy, 1080 unless you say otherwise
  -s, --server SERVER  the server, by name, id or role
```

Uses SSH. It connects as the deploy user to one or more of the app's servers, so your key has to be on them (and should be had you provision your server through Hatchbox. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

## hatchbox ps:start

Turn a stopped process back on.

```
Usage: hatchbox ps:start TYPE

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --no-wait        return once Hatchbox has queued it, without waiting for it to finish
```

## hatchbox ps:stop

Turn a process off.

```
Usage: hatchbox ps:stop TYPE

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --no-wait        return once Hatchbox has queued it, without waiting for it to finish
```

Aliases: `ps:kill`

## hatchbox ps:update

Change a process.

```
Usage: hatchbox ps:update TYPE [--start COMMAND] [--roles LIST] ...

Flags:
  -a, --app APP                    app to run command against
  -r, --remote REMOTE              remote saved for this repo in ~/.hatchbox to run command against
      --name NAME                  process name, letters, numbers, hyphens and underscores
      --start COMMAND              the command that runs
      --stop COMMAND               command systemd runs to stop it
      --reload COMMAND             command systemd runs to reload it
      --roles LIST                 comma-separated roles
      --server SERVER              one server to run on instead of roles, by name or id
      --systemd-type TYPE          simple or oneshot
      --[no-]socket                systemd socket activation, at most one process per app
      --[no-]restart-on-deploy     restart it on every deploy, which is the default
      --[no-]appsignal             run it under appsignal-wrap
      --appsignal-options OPTIONS  extra flags for appsignal-wrap
      --no-wait                    return once Hatchbox has queued it, without waiting for it to finish
```

Examples:

```
$ hatchbox ps:update worker --start 'bundle exec sidekiq -c 10'
Updating worker on fpd... done
```
