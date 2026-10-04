# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      class Reboot < Hatchbox::Command
        include Hatchbox::Commands::Servers::Lookup

        describe("servers:reboot",
          summary: "reboot a server, taking everything on it down until it is back",
          usage: "servers:reboot SERVER",
          app: :optional,
          flags: [CLUSTER_FLAG, CONFIRM_FLAG, WAIT_FLAG])

        def call
          server = find_server(one_positional("SERVER"))
          confirm(expected: server["name"].to_s, lines: ["This command will reboot #{server["name"]}. Everything on it is down until it comes back."])
          log_id = (client.post(server_path(server, suffix: "reboot")).json || {})["id"]
          queued(message: "Rebooting #{server["name"]}", log_id: log_id)
        end
      end
    end
  end
end
