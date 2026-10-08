# hatchbox pg

manage PostgreSQL databases

* [`hatchbox pg:backups`](#hatchbox-pgbackups)
* [`hatchbox pg:backups:capture`](#hatchbox-pgbackupscapture)
* [`hatchbox pg:backups:download`](#hatchbox-pgbackupsdownload)
* [`hatchbox pg:backups:info`](#hatchbox-pgbackupsinfo)
* [`hatchbox pg:backups:schedule`](#hatchbox-pgbackupsschedule)
* [`hatchbox pg:backups:schedules`](#hatchbox-pgbackupsschedules)
* [`hatchbox pg:backups:test`](#hatchbox-pgbackupstest)
* [`hatchbox pg:backups:unschedule`](#hatchbox-pgbackupsunschedule)
* [`hatchbox pg:backups:url`](#hatchbox-pgbackupsurl)
* [`hatchbox pg:bloat`](#hatchbox-pgbloat)
* [`hatchbox pg:blocking`](#hatchbox-pgblocking)
* [`hatchbox pg:credentials:url`](#hatchbox-pgcredentialsurl)
* [`hatchbox pg:info`](#hatchbox-pginfo)
* [`hatchbox pg:kill`](#hatchbox-pgkill)
* [`hatchbox pg:killall`](#hatchbox-pgkillall)
* [`hatchbox pg:locks`](#hatchbox-pglocks)
* [`hatchbox pg:outliers`](#hatchbox-pgoutliers)
* [`hatchbox pg:ps`](#hatchbox-pgps)
* [`hatchbox pg:psql`](#hatchbox-pgpsql)
* [`hatchbox pg:pull`](#hatchbox-pgpull)
* [`hatchbox pg:vacuum-stats`](#hatchbox-pgvacuum-stats)

## hatchbox pg:backups

List database backups and the backup schedule.

```
Usage: hatchbox pg:backups [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --json           output in json format
```

DATABASE defaults to the app's PostgreSQL database.

## hatchbox pg:backups:capture

Take a backup now.

```
Usage: hatchbox pg:backups:capture [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --no-wait        return once Hatchbox has queued it, without waiting for it to finish
```

Schedule backups first with hatchbox pg:backups:schedule.

## hatchbox pg:backups:download

Download the latest backup.

```
Usage: hatchbox pg:backups:download [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -o, --output FILE    where to write it, the backup's own file name unless you say otherwise
```

## hatchbox pg:backups:info

Show the output of a backup.

```
Usage: hatchbox pg:backups:info [BACKUP_ID]

Flags:
  -a, --app APP            app to run command against
  -r, --remote REMOTE      remote saved for this repo in ~/.hatchbox to run command against
  -d, --database DATABASE  which database, when the app has more than one
```

Without BACKUP_ID, shows the most recent backup.

## hatchbox pg:backups:schedule

Schedule backups, or change where and how often they run.

```
Usage: hatchbox pg:backups:schedule [DATABASE] --at SCHEDULE

Flags:
  -a, --app APP                     app to run command against
  -r, --remote REMOTE               remote saved for this repo in ~/.hatchbox to run command against
      --at SCHEDULE                 cron expression or @hourly, @daily, @weekly, @monthly
      --provider PROVIDER           local, s3, azureblob, r2, spaces, gcs, wasabi or other
      --bucket BUCKET               bucket or container, for every provider but local
      --region REGION               for s3, spaces and wasabi
      --endpoint URL                for other, and optionally r2
      --access-key-id KEY           access key, or the storage account name on Azure
      --secret-access-key SECRET    secret key, asked for with --provider if none is stored or you pass --access-key-id
      --retention PERIOD            how long to keep them, like 7d or 6M
      --honeybadger-checkin-id ID   Honeybadger check-in to report runs to
      --appsignal-push-api-key KEY  AppSignal push key to monitor runs with
```

Only the settings you pass change, but every call turns backups on, so the first one needs the provider and its settings.

Examples:

```
$ hatchbox pg:backups:schedule --at @daily --provider s3 --region us-east-1 --bucket my-backups --access-key-id AKIA... --retention 7d
Secret access key:
Scheduling backups of DATABASE_URL (db_56237b230774)... done
```

## hatchbox pg:backups:schedules

Show the backup schedule of a database.

```
Usage: hatchbox pg:backups:schedules [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --json           output in json format
```

## hatchbox pg:backups:test

Upload a test file to the backup storage.

```
Usage: hatchbox pg:backups:test [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

## hatchbox pg:backups:unschedule

Stop backups.

```
Usage: hatchbox pg:backups:unschedule [DATABASE]

Flags:
  -a, --app APP           app to run command against
  -r, --remote REMOTE     remote saved for this repo in ~/.hatchbox to run command against
      --confirm DATABASE  the database's name, to skip the prompt
```

## hatchbox pg:backups:url

Get a temporary URL for the latest backup.

```
Usage: hatchbox pg:backups:url [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

## hatchbox pg:bloat

Show table and index bloat, the space dead rows are holding (ssh).

```
Usage: hatchbox pg:bloat [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

Uses SSH, unless the database has a public address. The connection goes through an SSH tunnel to the server holding the database, as the deploy user. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

## hatchbox pg:blocking

Display queries holding locks other queries are waiting to be released (ssh).

```
Usage: hatchbox pg:blocking [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

Uses SSH, unless the database has a public address. The connection goes through an SSH tunnel to the server holding the database, as the deploy user. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

## hatchbox pg:credentials:url

Show the connection information for a database.

```
Usage: hatchbox pg:credentials:url [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

Aliases: `pg:credentials`

## hatchbox pg:info

Show database information.

```
Usage: hatchbox pg:info [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

Aliases: `pg`

## hatchbox pg:kill

Cancel a running query (ssh).

```
Usage: hatchbox pg:kill PID [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -f, --force          terminate the connection instead of canceling its query
```

Uses SSH, unless the database has a public address. The connection goes through an SSH tunnel to the server holding the database, as the deploy user. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

## hatchbox pg:killall

Terminate every other connection to the database (ssh).

```
Usage: hatchbox pg:killall [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --confirm APP    the app's name, to skip the prompt
```

Only touches connections to this database, not the rest of a shared cluster.

Uses SSH, unless the database has a public address. The connection goes through an SSH tunnel to the server holding the database, as the deploy user. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

## hatchbox pg:locks

Display queries with active locks (ssh).

```
Usage: hatchbox pg:locks [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

Uses SSH, unless the database has a public address. The connection goes through an SSH tunnel to the server holding the database, as the deploy user. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

## hatchbox pg:outliers

Show the queries with the longest total execution time (ssh).

```
Usage: hatchbox pg:outliers [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -n, --num NUM        number of queries to show, 10 unless you say otherwise
  -t, --truncate       cut queries off at 40 characters
```

Needs the pg_stat_statements extension and PostgreSQL 13 or later.

Uses SSH, unless the database has a public address. The connection goes through an SSH tunnel to the server holding the database, as the deploy user. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

## hatchbox pg:ps

View the queries running on the database (ssh).

```
Usage: hatchbox pg:ps [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -v, --verbose        include idle connections
```

Uses SSH, unless the database has a public address. The connection goes through an SSH tunnel to the server holding the database, as the deploy user. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

## hatchbox pg:psql

Open a psql shell to the database (ssh).

```
Usage: hatchbox pg:psql [DATABASE | SQL]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -c, --command SQL    SQL command to run
  -f, --file FILE      SQL file to run
  -d, --database NAME  which PostgreSQL database, when the app has more than one
      --url            print the connection URI instead of connecting
      --direct         connect straight to the database host instead of through an SSH tunnel
      --dangerous      a session that can write, which it cannot by default
```

DATABASE is a database name or the config var it is attached as, like DATABASE_URL; anything else is run as SQL. psql's own flags go after --.

Uses SSH, unless the database has a public address. The connection goes through an SSH tunnel to the server holding the database, as the deploy user. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

Aliases: `psql`

Examples:

```
$ hatchbox pg:psql
$ hatchbox pg:psql -c 'select count(*) from users'
$ hatchbox pg:psql RED_DATABASE_URL --dangerous
```

## hatchbox pg:pull

Pull the database into a new local database (ssh).

```
Usage: hatchbox pg:pull SOURCE TARGET

Flags:
  -a, --app APP                    app to run command against
  -r, --remote REMOTE              remote saved for this repo in ~/.hatchbox to run command against
      --exclude-table-data TABLES  tables to copy without their data, separated by semicolons
      --direct                     connect straight to the database host instead of through an SSH tunnel
```

SOURCE is the app's database, like DATABASE_URL. TARGET is a local database name or URL, which must not exist yet; it is created with createdb. Needs pg_dump, pg_restore and createdb at least as new as the server.

Uses SSH, unless the database has a public address. The connection goes through an SSH tunnel to the server holding the database, as the deploy user. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.

Examples:

```
$ hatchbox pg:pull DATABASE_URL fpd_development
```

## hatchbox pg:vacuum-stats

Show dead rows and whether autovacuum is expected to run (ssh).

```
Usage: hatchbox pg:vacuum-stats [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

Uses SSH, unless the database has a public address. The connection goes through an SSH tunnel to the server holding the database, as the deploy user. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.
