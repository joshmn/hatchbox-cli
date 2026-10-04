# frozen_string_literal: true

module Hatchbox
  class Target
    class Messages
      def initialize(config:)
        @config = config
      end

      def no_app
        "No app specified.\nRun this command from an app folder or specify which app to use with --app APP."
      end

      def multiple
        first_env, first_app = config.apps.first
        [
          "Multiple remotes for #{config.location}",
          "Usage: --remote #{first_env}",
          "   or: --app #{first_app}",
          "This project has more than one remote and no default.",
          "Specify the app you want with --app or --remote, or set \"default\": \"#{first_env}\" for it.",
          "Remotes:"
        ].concat(config.apps.map { |env, slug| "#{slug} (#{env})" }).join("\n")
      end

      def remotes
        return "This project has no remotes yet. Add one with hatchbox git:remote -a APP." if config.envs.empty?

        "Remotes: #{config.envs.join(", ")}"
      end

      def ambiguous(name:, rows:)
        (["There is more than one app named #{name}. Use its id with --app:"] + rows.map { |row| "#{row[:slug]} (#{row[:account]})" }).join("\n")
      end

      private

      attr_reader :config
    end
  end
end
