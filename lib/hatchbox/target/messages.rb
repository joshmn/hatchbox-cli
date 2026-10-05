# frozen_string_literal: true

module Hatchbox
  class Target
    class Messages
      def initialize(config:)
        @config = config
      end

      def no_app
        "No app specified.\nSave a remote for this repo with hatchbox git:remote, or specify which app to use with --app APP."
      end

      def multiple
        first_env, first_app = config.apps.first
        [
          "Multiple remotes for #{config.location}, and none is the default",
          "Usage: --remote #{first_env}",
          "   or: --app #{first_app}",
          "Or set \"default\": \"#{first_env}\" for this repo in ~/.hatchbox.",
          "Remotes:"
        ].concat(config.apps.map { |env, slug| "#{slug} (#{env})" }).join("\n")
      end

      def remotes
        return "This project has no remotes yet. Add one with hatchbox git:remote -a APP." if config.envs.empty?

        "Remotes: #{config.envs.join(", ")}"
      end

      def ambiguous(name:, rows:)
        (["There is more than one app named #{name}. Pass one of these to --app:"] + rows.map { |row| "#{row[:slug]} (#{row[:account]})" }).join("\n")
      end

      private

      attr_reader :config
    end
  end
end
