# hatchbox deploy

deploy the app and stream the build

* [`hatchbox deploy`](#hatchbox-deploy)

## hatchbox deploy

Deploy the app's branch, or one commit, and stream the build.

```
Usage: hatchbox deploy

Flags:
  -a, --app APP        app to run command against
  -r, --remote REMOTE  remote saved for this repo in ~/.hatchbox to run command against
      --sha SHA        deploy this commit instead of the tip of the branch
      --no-wait        return once Hatchbox has queued it, without waiting for it to finish
```

Examples:

```
$ hatchbox deploy
Deploying main to fpd... queued, release 4212
-----> Starting deployment
...
Verifying deploy... done
```
