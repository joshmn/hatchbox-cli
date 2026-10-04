# frozen_string_literal: true

module Hatchbox
  module Commands
    module Apps
      class Rename < Hatchbox::Command
        describe "apps:rename",
          summary: "rename an app, which takes it down while it moves",
          usage: "apps:rename NEWNAME",
          args: { new_name: "NEWNAME" },
          aliases: ["rename"],
          flags: [[nil, "--confirm APP", "the app's current name, to skip the prompt"], WAIT_FLAG],
          help: [
            "Hatchbox stops the app's processes, moves its folder, reinstalls its services and",
            "cron jobs under the new name and reapplies Caddy, so the app is down while this",
            "runs. The app keeps its id, and any remote this repo has pointing at it is updated."
          ]

        def call
          new_name = args.new_name
          Hatchbox.check_name!(new_name)

          old = app.name
          raise Hatchbox::Error, "New name must be different from the current name." if new_name == old

          confirm(expected: old, lines: ["Renaming #{old} stops its processes and moves its folder, so it is down until this finishes."])
          log_id = (client.post("/apps/#{app_id}/rename", body: { "app" => { "name" => new_name } }).json || {})["id"]
          code = queued(message: "Renaming #{old} to #{new_name}", log_id: log_id)
          return code unless code.zero?

          moved = config.rename_app_id(app_id: app_id, slug: "#{app_id}-#{new_name}")
          moved.each { |remote| puts("remote #{remote} updated") }
          0
        end
      end
    end
  end
end
