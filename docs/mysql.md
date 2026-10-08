# hatchbox mysql

open a mysql shell to the app's MySQL database

* [`hatchbox mysql:cli`](#hatchbox-mysqlcli)

## hatchbox mysql:cli

Open a mysql shell to the app's MySQL database (ssh).

```
Usage: hatchbox mysql:cli [DATABASE | SQL]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -c, --command SQL    SQL statement to run
  -d, --database NAME  which MySQL database, when the app has more than one
      --url            print the connection URI instead of connecting
      --direct         connect straight to the database host instead of through an SSH tunnel
      --dangerous      a session that can write, which it cannot by default
```

Sessions start with SET SESSION TRANSACTION READ ONLY unless you pass --dangerous. The password goes in a temporary option file, so it stays out of the process list. DATABASE is a database name or the config var it is attached as; anything else is run as SQL. mysql's own flags go after --.

Uses SSH, unless the database has a public address. The connection goes through an SSH tunnel to the server holding the database, as the deploy user. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

Aliases: `mysql`

Examples:

```
$ hatchbox mysql:cli
$ hatchbox mysql:cli -c 'select count(*) from users'
```
