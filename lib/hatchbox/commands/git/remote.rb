# frozen_string_literal: true

module Hatchbox
  module Commands
    module Git
      class Remote < Hatchbox::Command
        describe("git:remote",
          summary: "add an app to .hatchbox, the way heroku adds a git remote",
          usage: "git:remote [FILTER]",
          aliases: ["setup"],
          app: false,
          flags: [[nil, "--as REMOTE", "the remote name, same as -r"]],
          help: [
            "Picks an app off your accounts, or takes the one named with -a, and writes it to",
            "the nearest .hatchbox (or a new one at the root of the repo you are in) under the",
            "remote named with -r. Without -a it looks for the app whose repo matches one of",
            "this repo's git remotes: one match is used as is, several are offered to pick",
            "from, and none falls back to every app your token can reach, narrowed to FILTER",
            "when you pass one. Without -r it asks, suggesting the end of the app's name when",
            "that looks like an environment, like qa in fpd-qa, and production otherwise.",
            "",
            "A .hatchbox holds one line per app, written the way the dashboard url spells it,",
            "then the remote name, and optionally which remote to use by default:",
            "",
            "  13673-fpd:production",
            "  20001-fpd-qa:qa",
            "  default = production",
            "",
            "Only the leading number is read by Hatchbox; the rest tells you which app it is.",
            "It also takes per remote SSH settings for logs, run, ps:exec and pg:psql:",
            "",
            "  ssh_user:production = deploy",
            "  ssh_host:production = 203.0.113.10",
            "  ssh_port:production = 22",
            "  app_dir:production = /home/deploy/fpd/current"
          ],
          examples: ["$ hatchbox git:remote -a fpd -r production", "set .hatchbox remote production to 13673-fpd"])

        def call
          usage_error("Only one filter at a time.") if positionals.length > 1
          Hatchbox::TokenStore.new(prompt: prompt).ensure_token
          @file = Hatchbox::Config.new(Hatchbox::ConfigLocator.target)
          slug = Hatchbox.blank?(session.app_flag) ? choose_app : resolve(session.app_flag)
          remote = options[:as] || session.remote_flag
          remote = ask_remote(Hatchbox::RemoteName.guess(slug)) if Hatchbox.blank?(remote)
          Hatchbox::RemoteName.validate(remote)
          return 1 unless replace?(remote: remote, slug: slug)

          file.set_app(env: remote, app: slug)
          puts("set .hatchbox remote #{remote} to #{slug}")
          choose_default
          0
        end

        private

        attr_reader :file

        def choose_app
          Hatchbox::AppChooser.new(catalog: session.catalog, prompt: prompt).choose(positionals.first)
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
          existing = file.exists? ? file.app_for(remote) : nil
          return true if Hatchbox.blank?(existing) || existing == slug

          ui.warning("#{remote} is already #{existing} in #{file.path}.")
          return true unless prompt.available? && Hatchbox.blank?(ENV["HATCHBOX_ASSUME_YES"])
          return true if prompt.yes?(question: "Point it at #{slug} instead? [y/N] ")

          $stderr.puts("Left alone.")
          false
        end

        def choose_default
          remotes = file.envs.uniq
          return if remotes.length < 2 || !Hatchbox.blank?(file.get("default"))

          ui.warning("#{file.path} has more than one remote now, so every command wants -r unless one is the default.")
          return unless prompt.available?

          answer = prompt.ask(question: "Default remote (blank to always pass -r): ")
          return if Hatchbox.blank?(answer)
          return ui.warning("No remote called #{answer}, so the default is unset.") unless remotes.include?(answer)

          file.set(key: "default", value: answer)
          puts("default remote is #{answer}")
        end
      end
    end
  end
end
