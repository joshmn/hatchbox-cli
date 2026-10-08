# hatchbox redis

open a redis-cli session to the app's Redis

* [`hatchbox redis:cli`](#hatchbox-rediscli)

## hatchbox redis:cli

Open a redis-cli session to the app's Redis (ssh).

```
Usage: hatchbox redis:cli [DATABASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --direct         connect straight to the Redis host instead of through an SSH tunnel
```

redis-cli's own arguments go after --.

Uses SSH, unless the database has a public address. The connection goes through an SSH tunnel to the server holding the database, as the deploy user. A user, host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags.
