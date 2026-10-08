# hatchbox logs

display logs for an app, read from its servers over SSH

* [`hatchbox logs`](#hatchbox-logs)

## hatchbox logs

Display recent log output (ssh).

```
Usage: hatchbox logs [PROCESS]

Flags:
  -a, --app APP            app to run command against
  -r, --remote REMOTE      remote saved for this repo in ~/.hatchbox to run command against
  -n, --num NUM            number of lines to display
  -t, --tail               continually stream logs
  -f, --follow             same as --tail
      --run ID             the output of a hatchbox run:detached, by the id it printed
  -p, --process-type TYPE  only this process type
      --ps TYPE            same as --process-type
  -s, --source SOURCE      only app lines or only systemd lines
      --server SERVER      only the server with this name, id or role
      --since WHEN         only lines since WHEN, in any form journalctl --since takes, like '1 hour ago'
      --units              list the systemd units it would read on each server, and stop
      --force-colors       force use of colors even on non-tty output
```

Reads the journal of each process's systemd unit on every server the app's processes run on, and merges the lines by time.

app lines are the process's own output. systemd lines are systemd reporting that the process started, stopped or crashed.

Uses SSH. It connects as the deploy user to one or more of the app's servers, so your key has to be on them (and should be had you provision your server through Hatchbox. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

Examples:

```
$ hatchbox logs --tail
2026-09-19T15:04:05.123456+00:00 app[server@web-1]: Started GET "/" for 203.0.113.9
2026-09-19T15:04:06.000000+00:00 systemd[sidekiq@worker-1]: Started fpd-sidekiq.service.

$ hatchbox logs -p sidekiq -n 500 --since '1 hour ago'
```
