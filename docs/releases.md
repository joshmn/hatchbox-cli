# hatchbox releases

manage app releases and roll back

* [`hatchbox releases`](#hatchbox-releases)
* [`hatchbox releases:info`](#hatchbox-releasesinfo)
* [`hatchbox releases:output`](#hatchbox-releasesoutput)
* [`hatchbox releases:rollback`](#hatchbox-releasesrollback)

## hatchbox releases

Display the app's release history.

```
Usage: hatchbox releases

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -n, --num NUM        number of releases to display
      --page PAGE      page of older releases
      --json           output in json format
```

hatchbox releases:output reads any id listed here.

## hatchbox releases:info

View detailed information for a release.

```
Usage: hatchbox releases:info [RELEASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --json           output in json format
```

RELEASE is an id from hatchbox releases, or deploy or restart for the latest one. It defaults to the latest release.

## hatchbox releases:output

View the output of a release, following it while it runs.

```
Usage: hatchbox releases:output [RELEASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

RELEASE is an id from hatchbox releases, or deploy or restart for the latest one. Any Hatchbox log id works here, including ones from server and database activity.

Aliases: `builds:output`

## hatchbox releases:rollback

Redeploy the commit of an earlier release.

```
Usage: hatchbox releases:rollback [RELEASE]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --no-wait        return once Hatchbox has queued it, without waiting for it to finish
```

Without RELEASE, goes back to the newest successful deploy of a different commit than the one live now.

Aliases: `rollback`
