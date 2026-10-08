# hatchbox scripts

list the runs of custom scripts

* [`hatchbox scripts:activity`](#hatchbox-scriptsactivity)

## hatchbox scripts:activity

List the runs of a custom script.

```
Usage: hatchbox scripts:activity SCRIPT

Flags:
  -n, --num NUM  number of runs
      --json     output in json format
```

SCRIPT is the id from the script's dashboard URL, like 42 in /scripts/42-clear-the-cache. What the script printed on each server isn't here; that's in hatchbox servers:activity.
