# frozen_string_literal: true

module Hatchbox
  class TargetMessages
    def initialize(config:)
      @config = config
    end

    def no_app
      "No app specified.\nRun this command from an app folder or specify which app to use with --app APP."
    end

    def multiple
      first_env, first_app = config.apps.first
      [
        "Multiple apps in #{config.path}",
        "Usage: --remote #{first_env}",
        "   or: --app #{first_app}",
        "Your .hatchbox names more than one app and has no default line.",
        "Specify the app you want with --app or --remote, or add default = #{first_env} to it.",
        "Remotes in #{config.path}:"
      ].concat(config.apps.map { |env, slug| "#{slug} (#{env})" }).join("\n")
    end

    def remotes
      return "It names no apps. Add one with hatchbox git:remote -a APP." if config.envs.empty?

      "Remotes: #{config.envs.uniq.join(", ")}"
    end

    def ambiguous(name:, rows:)
      (["There is more than one app named #{name}. Use its id with --app:"] + rows.map { |row| "#{row[:slug]} (#{row[:account]})" }).join("\n")
    end

    private

    attr_reader :config
  end
end
