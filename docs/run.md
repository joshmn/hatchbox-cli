# hatchbox run

run a command on one of the app's servers

* [`hatchbox run`](#hatchbox-run)
* [`hatchbox run:detached`](#hatchbox-rundetached)

## hatchbox run

Run a command on one of the app's servers (ssh).

```
Usage: hatchbox run COMMAND

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -e, --env ENV        environment variables to set, like FOO=bar;BAZ=qux
  -s, --server SERVER  the server to run on, by name, id or role
      --no-tty         force the command to not run in a tty
```

Runs in a login shell from the app's current release, on the first server carrying an app role unless -s picks one. A command starting with rails runs as bin/rails and stops if the release directory is missing. Flags meant for the command go after --.

Uses SSH. It connects as the deploy user to one or more of the app's servers, so your key has to be on them (and should be had you provision your server through Hatchbox. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

Examples:

```
$ hatchbox run rails console
Running `rails console` on fpd... up, web-1

$ hatchbox run -- ls -la
```

## hatchbox run:detached

Run a command on a server in the background (ssh).

```
Usage: hatchbox run:detached COMMAND

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -e, --env ENV        environment variables to set, like FOO=bar;BAZ=qux
  -s, --server SERVER  the server to run on, by name, id or role
```

Starts the command with nohup and setsid so it outlives the SSH session, and sends its output to the journal through systemd-cat, tagged so hatchbox logs --run ID reads it back.

Uses SSH. It connects as the deploy user to one or more of the app's servers, so your key has to be on them (and should be had you provision your server through Hatchbox. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

Examples:

```
$ hatchbox run:detached rake db:backfill
Running `rake db:backfill` on fpd... done, run 20260919150405
Run hatchbox logs --app fpd --run 20260919150405 to view the output.
```
