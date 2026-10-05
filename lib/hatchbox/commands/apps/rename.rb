# frozen_string_literal: true

module Hatchbox
  module Commands
    module Apps
      class Rename < Hatchbox::Command
        describe "apps:rename",
          summary: "rename an app",
          args: { new_name: "NEWNAME" },
          aliases: ["rename"],
          flags: [[nil, "--confirm APP", "the app's current name, to skip the prompt"], WAIT_FLAG],
          help: ["Any remote this repo has pointing at the app is updated to the new name."]

        def call
          new_name = args.new_name
          Hatchbox.check_name!(new_name)

          old = app.name
          raise Hatchbox::Error, "New name must be different from the current name." if new_name == old

          confirm(expected: old, lines: ["This command will rename #{old} to #{new_name}."])
          log_id = (client.post("/apps/#{app_id}/rename", body: { "app" => { "name" => new_name } }).json || {})["id"]
          code = queued(message: "Renaming #{old} to #{new_name}", log_id: log_id)
          return code unless code.zero?

          moved = config.rename_app_id(app_id: app_id, slug: "#{app_id}-#{new_name}")
          moved.each { |remote| puts("set remote #{remote} to #{app_id}-#{new_name} for #{config.location}") }
          0
        end
      end
    end
  end
end
