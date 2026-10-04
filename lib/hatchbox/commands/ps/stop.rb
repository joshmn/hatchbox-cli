# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Stop < Hatchbox::Command
        include Hatchbox::Commands::Ps::Toggle

        describe("ps:stop",
          summary: "turn a process off and leave it off",
          usage: "ps:stop TYPE",
          aliases: ["ps:kill"],
          flags: [WAIT_FLAG],
          help: [
            "Unlike heroku, a stopped process stays stopped through deploys and restarts until",
            "hatchbox ps:start turns it back on."
          ])

        def call
          process = toggled_process
          data = client.delete("/apps/#{app_id}/processes/#{process["id"]}/activation").json || {}
          toggled(data: data, message: "Stopping #{process["name"]} on #{label}", already: "it was already off")
        end
      end
    end
  end
end
