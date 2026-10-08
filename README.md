# hatchbox

A Heroku-style command line for [Hatchbox](https://hatchbox.io). If your body remember how to use the `heroku` CLI, you'll feel at home.

## Installation

```bash
gem install hatchbox
```

Cool.

## Logging in

Hatchbox has no password login for its API. Make one at https://hatchbox.io/api_tokens and then:

```bash
hatchbox login
```

## Pointing a repo at an app

From inside a repo:

```bash
hatchbox setup
```

will pull all your apps and guess which one matches your git remotes.

## Everything goes in `~/.hatchbox`

Everything is keyed with one entry per repo (per the repo's path) with its remotes and includes any SSH overrides. 

```json
{
  "token": "...",
  "projects": {
    "/Users/you/code/fpd": {
      "remotes": { "production": "13673-fpd", "qa": "20001-fpd-qa" },
      "default": "production",
      "ssh": {
        "production": { "user": "deploy", "host": "203.0.113.10", "port": 22, "app_dir": "/home/deploy/fpd/current" }
      }
    }
  }
}
```

You shouldn't need to touch this unless you use a jumpbox.

## Using it

Auto-generated docs from the CLI are in [docs](/docs).

The ones you'll use most often:

```bash
hatchbox apps
hatchbox deploy
hatchbox logs --tail
hatchbox run rails console
hatchbox config:set RAILS_ENV=production
hatchbox ps:restart sidekiq
hatchbox pg:psql
hatchbox releases:rollback
```

(Chris: I need `config:unset` and `config`)

## Kind of important differences

These behave differently from Heroku:

* Config var values are write-only (the API never returns them), so `config` lists names.
  * chris, please.
* `ps:stop` keeps a process off through deploys and restarts until `ps:start` turns it back on; this is Hatchbox behavior.
* `rollback` redeploys an older commit, since Hatchbox has no releases to restore.
* `pg:psql` and `mysql:cli` sessions are read only unless you pass `--dangerous`.

## Plugins

A plugin adds commands, and is a poorly documented feature because I don't know if anyone will use it; perhaps someone will make a sql suite:

```bash
hatchbox plugins:install hatchbox-acme
hatchbox plugins:install ./script/hatchbox_commands.rb
```

```json
{
  "plugins": ["hatchbox-acme", "/Users/joshmn/code/rails/hehestreams/script/hatchbox_commands.rb"]
}
```

To get rid of one:

```bash
hatchbox plugins:uninstall hatchbox-acme
```

A plugin that won't load (syntax error, the dog is outside, whatever) gets a warning and everything else keeps working. It's also boring-ass Ruby class running with your API token.

### Writing one

A command is a class that inherits from `Hatchbox::Command` and calls `describe`. This one adds `hatchbox console`:

```ruby
require "hatchbox"

module AcmeHatchbox
  class Console < Hatchbox::Command
    describe "console",
      summary: "open a rails console on one of the app's servers",
      ssh: :shell,
      flags: [SERVER_FLAG, [nil, "--sandbox", "roll back any changes when the console exits"]],
      examples: ["$ hatchbox console --sandbox", "Opening a console on hehestreams ..."]

    def call
      target = ssh_target(server: options.server)
      rails = options.sandbox ? "exec bin/rails console --sandbox" : "exec bin/rails console"
      ui.action("Opening a console on #{label}") { |step| step.status = "up, #{target.label}" }
      Hatchbox.run(target.ssh(command: target.login_shell("#{target.enter_or_stop}\n#{rails}"), tty: true))
    end
  end
end
```

Please see the other commands for inspiration: [lib/hatchbox/commands](lib/hatchbox/commands)

## Contributing

Include your favorite recipe in your hand-rolled PR; I'll ignore it otherwise, sorry.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
