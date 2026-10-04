# frozen_string_literal: true

module Hatchbox
  module Commands
    module Apps
      class Destroy < Hatchbox::Command
        describe("apps:destroy",
          summary: "permanently destroy an app",
          usage: "apps:destroy [APP]",
          aliases: ["destroy"],
          flags: [[nil, "--confirm APP", "the app's name, to skip the prompt"], WAIT_FLAG],
          help: [
            "Deletes the app's folder and services from every server and detaches its",
            "databases. The databases themselves are kept. This cannot be undone. Any",
            ".hatchbox remote pointing at the app is removed."
          ])

        def call
          usage_error("Only one app at a time.") if positionals.length > 1
          name = app.name
          confirm(expected: name, lines: ["This command will destroy #{name}, its folder and services on every server.", "Its databases are detached, not deleted."])
          log_id = (client.delete("/apps/#{app_id}", body: { "name" => name }).json || {})["id"]
          code = queued(message: "Destroying #{name} (databases are detached, not deleted)", log_id: log_id, gone_ok: true)
          return code unless code.zero?

          gone = config.remove_app_id(app_id)
          ui.note("removed #{formatter.list(gone)} from #{config.path}") if gone.any?
          0
        end

        private

        def positional_app
          positionals.first
        end
      end
    end
  end
end
