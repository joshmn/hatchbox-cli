# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Start < Hatchbox::Command
        include Hatchbox::Commands::Ps::Toggle

        describe "ps:start",
          summary: "turn a stopped process back on",
          usage: "ps:start TYPE",
          args: { type: "TYPE" },
          flags: [WAIT_FLAG]

        def call
          process = toggled_process
          data = client.post("/apps/#{app_id}/processes/#{process["id"]}/activation").json || {}
          toggled(data: data, message: "Starting #{process["name"]} on #{label}", already: "it was already on")
        end
      end
    end
  end
end
