# frozen_string_literal: true

module Hatchbox
  module Commands
    module Apps
      class Destroy < Hatchbox::Command
        describe "apps:destroy",
          summary: "permanently destroy an app",
          usage: "apps:destroy [APP]",
          args: { app: "[APP]" },
          aliases: ["destroy"],
          flags: [[nil, "--confirm APP", "the app's name, to skip the prompt"], WAIT_FLAG],
          help: [
            "Deletes the app's folder and services from every server and detaches its",
            "databases. The databases themselves are kept. This cannot be undone. Any remote",
            "this repo has pointing at the app is removed from ~/.hatchbox."
          ]

        def call
          name = app.name
          confirm(expected: name, lines: ["This command will destroy #{name}, its folder and services on every server.", "Its databases are detached, not deleted."])
          log_id = (client.delete("/apps/#{app_id}", body: { "name" => name }).json || {})["id"]
          code = queued(message: "Destroying #{name} (databases are detached, not deleted)", log_id: log_id, gone_ok: true)
          return code unless code.zero?

          gone = config.remove_app_id(app_id)
          ui.note("removed #{formatter.list(gone)} from #{config.location}") if gone.any?
          0
        end

        private

        def positional_app
          args.app
        end
      end
    end
  end
end
