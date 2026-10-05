# frozen_string_literal: true

module Hatchbox
  module Commands
    module Apps
      class Destroy < Hatchbox::Command
        describe "apps:destroy",
          summary: "permanently destroy an app",
          args: { app: "[APP]" },
          aliases: ["destroy"],
          flags: [CONFIRM_APP_FLAG, WAIT_FLAG],
          help: ["Any remote this repo has pointing at the app is removed from ~/.hatchbox."]

        def call
          name = app.name
          confirm(expected: name, lines: ["This command will destroy #{name}."])
          log_id = (client.delete("/apps/#{app_id}", body: { "name" => name }).json || {})["id"]
          code = queued(message: "Destroying #{name}", log_id: log_id, gone_ok: true)
          return code unless code.zero?

          gone = config.remove_app_id(app_id)
          ui.note("removed #{formatter.list(gone)} from the remotes for #{config.location}") if gone.any?
          0
        end
      end
    end
  end
end
