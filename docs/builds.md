# hatchbox builds

list the app's deploys

* [`hatchbox builds`](#hatchbox-builds)
* [`hatchbox builds:info`](#hatchbox-buildsinfo)

## hatchbox builds

List the app's deploys.

```
Usage: hatchbox builds

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
  -n, --num NUM        number of builds to display
      --json           output in json format
```

## hatchbox builds:info

View detailed information for a build.

```
Usage: hatchbox builds:info [BUILD]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --json           output in json format
```

BUILD is an id from hatchbox builds. It defaults to the latest deploy.
