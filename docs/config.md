# hatchbox config

manage app config vars

* [`hatchbox config`](#hatchbox-config)
* [`hatchbox config:get`](#hatchbox-configget)
* [`hatchbox config:set`](#hatchbox-configset)
* [`hatchbox config:unset`](#hatchbox-configunset)

## hatchbox config

Display the config vars set on an app.

```
Usage: hatchbox config

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --json           output in json format
```

Hatchbox's API only returns config var names, never their values.

Aliases: `config:list`

## hatchbox config:get

Check whether a config var is set.

```
Usage: hatchbox config:get KEY

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

Hatchbox never returns config var values, so this can only say whether KEY is set, and exits 1 either way.

## hatchbox config:set

Set one or more config vars.

```
Usage: hatchbox config:set KEY1=VALUE1 [KEY2=VALUE2 ...]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

Names are uppercased before they're sent and can only use letters, numbers and underscores. A value typed here lands in your shell history like anything else on the command line.

Examples:

```
$ hatchbox config:set RAILS_ENV=production RACK_ENV=production
Setting RAILS_ENV, RACK_ENV on fpd... done
RAILS_ENV: production
RACK_ENV:  production
```

## hatchbox config:unset

Unset one or more config vars.

```
Usage: hatchbox config:unset KEY1 [KEY2 ...]

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

Aliases: `config:remove`
