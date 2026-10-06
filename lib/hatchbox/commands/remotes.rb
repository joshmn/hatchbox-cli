# frozen_string_literal: true

module Hatchbox
  module Commands
    class Remotes < Hatchbox::Command
      describe "remotes",
        summary: "list the remotes saved for this repo",
        aliases: ["envs", "git:remotes"],
        app: false

      def call
        raise Hatchbox::Error, "No remotes for #{config.location}. Add one with hatchbox git:remote." unless config.exists?

        ui.header(config.location)
        current = current_remote
        width = config.remotes.map { |name| name.length }.max.to_i
        config.apps.each do |name, slug|
          puts("#{name.ljust(width)}  #{slug}#{name == current ? color.green("  (default)") : ""}")
        end
        0
      end

      private

      def current_remote
        session.target.remote
      rescue Hatchbox::Error
        nil
      end
    end
  end
end
