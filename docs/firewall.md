# hatchbox firewall

manage a server's firewall rules

* [`hatchbox firewall`](#hatchbox-firewall)
* [`hatchbox firewall:add`](#hatchbox-firewalladd)
* [`hatchbox firewall:info`](#hatchbox-firewallinfo)
* [`hatchbox firewall:remove`](#hatchbox-firewallremove)

## hatchbox firewall

List a server's firewall rules.

```
Usage: hatchbox firewall SERVER

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER  the cluster, by name or id, instead of the app's
      --json             output in json format
```

Aliases: `firewall:list`

## hatchbox firewall:add

Add a firewall rule to a server.

```
Usage: hatchbox firewall:add SERVER PORT

Flags:
  -a, --app APP           app to run command against
  -r, --remote REMOTE     remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER   the cluster, by name or id, instead of the app's
      --from ADDRESS      an IP address or CIDR range, anywhere unless you pass one
      --deny              deny the traffic instead of allowing it
      --description TEXT  a note for yourself
      --no-wait           return once Hatchbox has queued it, without waiting for it to finish
```

Examples:

```
$ hatchbox firewall:add web-1 9000 --from 203.0.113.0/24 --description 'Metrics scraper'
Allowing port 9000 from 203.0.113.0/24 on web-1... done
```

## hatchbox firewall:info

Show one firewall rule.

```
Usage: hatchbox firewall:info SERVER RULE

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER  the cluster, by name or id, instead of the app's
      --json             output in json format
```

## hatchbox firewall:remove

Remove a firewall rule from a server.

```
Usage: hatchbox firewall:remove SERVER RULE

Flags:
  -a, --app APP          app to run command against
  -r, --remote REMOTE    remote saved for this repo in ~/.hatchbox to run command against
      --cluster CLUSTER  the cluster, by name or id, instead of the app's
      --no-wait          return once Hatchbox has queued it, without waiting for it to finish
```

Aliases: `firewall:delete`
