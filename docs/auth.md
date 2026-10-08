# hatchbox auth

log in and out, and see what the token reaches

* [`hatchbox auth:login`](#hatchbox-authlogin)
* [`hatchbox auth:logout`](#hatchbox-authlogout)
* [`hatchbox auth:token`](#hatchbox-authtoken)
* [`hatchbox auth:whoami`](#hatchbox-authwhoami)

## hatchbox auth:login

Log in with a Hatchbox API token.

```
Usage: hatchbox auth:login

Flags:
      --token TOKEN  use this token instead of asking for one, which puts it in your shell history
```

Hatchbox's API has no password login, so this asks for an API token, checks it against your accounts, and saves it to ~/.hatchbox. Make one at https://hatchbox.io/api_tokens.

Aliases: `login`

Examples:

```
$ hatchbox login
Enter your Hatchbox API token. Make one at https://hatchbox.io/api_tokens
Token:
Logging in... done
Logged in with access to My Team
```

## hatchbox auth:logout

Clear the saved API token.

```
Usage: hatchbox auth:logout
```

Removes the saved token from ~/.hatchbox.

Aliases: `logout`

## hatchbox auth:token

Display the API token in use.

```
Usage: hatchbox auth:token
```

Prints the token hatchbox would use here.

## hatchbox auth:whoami

Display the accounts the API token can reach.

```
Usage: hatchbox auth:whoami
```

Hatchbox's API has no endpoint that says who a token belongs to, so this lists the accounts it can act on and where the token came from.

Aliases: `whoami`
