# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Destroy < Hatchbox::Command
        describe "ps:destroy",
          summary: "stop a process and delete it from every server",
          usage: "ps:destroy TYPE",
          args: { type: "TYPE" },
          flags: [[nil, "--confirm TYPE", "the process name, to skip the prompt"], WAIT_FLAG]

        def call
          process = app.formation.find_process(args.type)
          name = process["name"].to_s
          confirm(expected: name, lines: ["This command will stop #{name} and remove its systemd unit from every server on #{label}."])
          log_id = (client.delete("/apps/#{app_id}/processes/#{process["id"]}").json || {})["id"]
          queued(message: "Destroying #{name} on #{label}", log_id: log_id)
        end
      end
    end
  end
end
