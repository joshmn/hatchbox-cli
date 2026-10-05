# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Stop < Hatchbox::Command
        describe "ps:stop",
          summary: "turn a process off",
          args: { type: "TYPE" },
          aliases: ["ps:kill"],
          flags: [WAIT_FLAG]

        def call
          process = app.formation.find_process(args.type)
          data = client.delete("/apps/#{app_id}/processes/#{process["id"]}/activation").json || {}
          queued_or_done(message: "Stopping #{process["name"]} on #{label}", log_id: data["log_id"], status: "done, it was already off")
        end
      end
    end
  end
end
