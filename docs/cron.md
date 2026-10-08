# hatchbox cron

manage the app's cron jobs

* [`hatchbox cron`](#hatchbox-cron)
* [`hatchbox cron:add`](#hatchbox-cronadd)
* [`hatchbox cron:info`](#hatchbox-croninfo)
* [`hatchbox cron:remove`](#hatchbox-cronremove)
* [`hatchbox cron:update`](#hatchbox-cronupdate)

## hatchbox cron

List the app's cron jobs.

```
Usage: hatchbox cron

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --json           output in json format
```

hatchbox run -s cron 'journalctl -u cron' shows when they ran.

Aliases: `cron:list`

## hatchbox cron:add

Add a cron job.

```
Usage: hatchbox cron:add COMMAND --at SCHEDULE

Flags:
  -a, --app APP                    app to run command against
  -r, --remote REMOTE              remote saved for this repo in ~/.hatchbox to run command against
      --at SCHEDULE                cron expression or @hourly, @daily, @weekly, @monthly
      --name NAME                  a label for the job
      --[no-]appsignal             wrap it in AppSignal cron monitoring
      --honeybadger-checkin-id ID  Honeybadger check-in to report to, or an empty string to stop
```

The name defaults to the command. Flags meant for the command go after --.

Aliases: `cron:create`

Examples:

```
$ hatchbox cron:add bin/rails sync:nightly --at '0 0 * * *' --name 'Nightly sync'
Adding Nightly sync to fpd... done
```

## hatchbox cron:info

Show one cron job.

```
Usage: hatchbox cron:info JOB

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --json           output in json format
```

## hatchbox cron:remove

Remove a cron job.

```
Usage: hatchbox cron:remove JOB

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

Aliases: `cron:destroy`, `cron:delete`

## hatchbox cron:update

Change a cron job.

```
Usage: hatchbox cron:update JOB

Flags:
  -a, --app APP                    app to run command against
  -r, --remote REMOTE              remote saved for this repo in ~/.hatchbox to run command against
      --at SCHEDULE                cron expression or @hourly, @daily, @weekly, @monthly
      --name NAME                  a label for the job
      --[no-]appsignal             wrap it in AppSignal cron monitoring
      --honeybadger-checkin-id ID  Honeybadger check-in to report to, or an empty string to stop
      --command COMMAND            the command to run
```
