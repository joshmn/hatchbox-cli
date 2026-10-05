# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Restart < Hatchbox::Command
        describe "ps:restart",
          summary: "restart every process, or one process type",
          args: { type: "[TYPE]" },
          aliases: ["restart"],
          flags: [WAIT_FLAG]

        def call
          return restart_all if args.type.nil?

          process = app.formation.find_process(args.type)
          log_id = (client.post("/apps/#{app_id}/processes/#{process["id"]}/restart").json || {})["id"]
          queued(message: "Restarting #{process["name"]} on #{label}", log_id: log_id)
        end

        private

        def restart_all
          log_id = (client.post("/apps/#{app_id}/restart").json || {})["id"]
          queued(message: "Restarting all processes on #{label}", log_id: log_id)
        end
      end
    end
  end
end
