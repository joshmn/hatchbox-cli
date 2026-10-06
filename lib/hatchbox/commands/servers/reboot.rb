# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      class Reboot < Hatchbox::Command
        include Hatchbox::Commands::Servers::Lookup

        describe "servers:reboot",
          summary: "reboot a server",
          args: { server: "SERVER" },
          flags: [CLUSTER_FLAG, CONFIRM_FLAG, WAIT_FLAG]

        def call
          server = find_server(args.server)
          confirm(expected: server["name"].to_s, lines: ["This command will reboot #{server["name"]}."])
          log_id = (client.post(server_path(server, suffix: "reboot")).json || {})["id"]
          queued(message: "Rebooting #{server["name"]}", log_id: log_id)
        end
      end
    end
  end
end
