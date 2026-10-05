# frozen_string_literal: true

module Hatchbox
  module Commands
    module Git
      class Remote < Hatchbox::Command
        describe "git:remote",
          summary: "save an app as a remote for this repo",
          args: { filter: "[FILTER]" },
          aliases: ["setup"],
          app: false,
          flags: [[nil, "--as REMOTE", "the remote name, same as -r"]],
          help: [
            "Picks an app off your accounts, or takes the one named with -a, and saves it in",
            "~/.hatchbox for the repo you are in (or this folder, outside a repo) under the",
            "remote named with -r. Without -a it guesses from this repo's git remotes and puts",
            "that app at the top of the list, so enter takes it; otherwise pick one by number,",
            "id or name. FILTER narrows the list. Without a terminal, a single match is used",
            "as is. Without -r it asks, suggesting the end of the app's name when that looks",
            "like an environment, like qa in fpd-qa, and production otherwise.",
            "",
            "~/.hatchbox is JSON. Each project is keyed by its repo's path and holds its",
            "remotes, an optional default, and optional SSH settings per remote for logs, run,",
            "ps:exec and the database commands:",
            "",
            "  \"projects\": {",
            "    \"/Users/you/code/fpd\": {",
            "      \"remotes\": { \"production\": \"13673-fpd\", \"qa\": \"20001-fpd-qa\" },",
            "      \"default\": \"production\",",
            "      \"ssh\": {",
            "        \"production\": {",
            "          \"user\": \"deploy\", \"host\": \"203.0.113.10\", \"port\": 22,",
            "          \"app_dir\": \"/home/deploy/fpd/current\"",
            "        }",
            "      }",
            "    }",
            "  }",
            "",
            "Only the leading number of each app is read; the rest tells you which app it is."
          ],
          examples: ["$ hatchbox git:remote -a fpd -r production", "set remote production to 13673-fpd for ~/code/fpd in ~/.hatchbox"]

        def call
          Hatchbox::TokenStore.new(prompt: prompt).ensure_token
          slug = Hatchbox.blank?(session.app_flag) ? choose_app : resolve(session.app_flag)
          remote = options.as || session.remote_flag
          remote = ask_remote(Hatchbox::RemoteName.guess(slug)) if Hatchbox.blank?(remote)
          Hatchbox::RemoteName.validate(remote)
          return 1 unless replace?(remote: remote, slug: slug)

          config.set_app(env: remote, app: slug)
          puts("set remote #{remote} to #{slug} for #{config.location}")
          choose_default
          0
        end

        private

        def choose_app
          Hatchbox::App::Chooser.new(catalog: session.catalog, prompt: prompt).choose(args.filter)
        end

        def resolve(value)
          lookup = Hatchbox::Session.new(app_flag: value)
          "#{lookup.app_id}-#{lookup.app.name}"
        end

        def ask_remote(suggested)
          return suggested unless prompt.available?

          answer = prompt.ask(question: "Remote name [#{suggested}]: ")
          Hatchbox.blank?(answer) ? suggested : answer
        end

        def replace?(remote:, slug:)
          existing = config.app_for(remote)
          return true if Hatchbox.blank?(existing) || existing == slug

          ui.warning("#{remote} is already #{existing} for #{config.location}.")
          return true unless prompt.available? && Hatchbox.blank?(ENV["HATCHBOX_ASSUME_YES"])
          return true if prompt.yes?(question: "Point it at #{slug} instead? [y/N] ")

          $stderr.puts("Left alone.")
          false
        end

        def choose_default
          remotes = config.envs
          return if remotes.length < 2 || !config.default.nil?

          ui.warning("#{config.location} has more than one remote now, so every command wants -r unless one is the default.")
          return unless prompt.available?

          answer = prompt.ask(question: "Default remote (blank to always pass -r): ")
          return if Hatchbox.blank?(answer)
          return ui.warning("No remote called #{answer}, so the default is unset.") unless remotes.include?(answer)

          config.set_default(answer)
          puts("default remote is #{answer}")
        end
      end
    end
  end
end
