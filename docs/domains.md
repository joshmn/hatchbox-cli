# hatchbox domains

manage the app's domains

* [`hatchbox domains`](#hatchbox-domains)
* [`hatchbox domains:add`](#hatchbox-domainsadd)
* [`hatchbox domains:clear`](#hatchbox-domainsclear)
* [`hatchbox domains:info`](#hatchbox-domainsinfo)
* [`hatchbox domains:remove`](#hatchbox-domainsremove)
* [`hatchbox domains:update`](#hatchbox-domainsupdate)

## hatchbox domains

List the app's domains.

```
Usage: hatchbox domains

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --json           output in json format
```

## hatchbox domains:add

Add a domain to the app.

```
Usage: hatchbox domains:add HOSTNAME

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

## hatchbox domains:clear

Remove every domain from the app.

```
Usage: hatchbox domains:clear

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --confirm APP    the app's name, to skip the prompt
```

## hatchbox domains:info

Show one of the app's domains.

```
Usage: hatchbox domains:info HOSTNAME

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --json           output in json format
```

## hatchbox domains:remove

Remove a domain from the app.

```
Usage: hatchbox domains:remove HOSTNAME

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```

Aliases: `domains:delete`

## hatchbox domains:update

Rename one of the app's domains.

```
Usage: hatchbox domains:update HOSTNAME NEWHOSTNAME

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
```
