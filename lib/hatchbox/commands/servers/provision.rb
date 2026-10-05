# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      class Provision < Hatchbox::Command
        include Hatchbox::Commands::Servers::Lookup

        describe "servers:provision",
          summary: "rerun provisioning on a server, the dashboard's Update button",
          args: { server: "SERVER" },
          app: :optional,
          flags: [CLUSTER_FLAG, CONFIRM_FLAG, WAIT_FLAG]

        def call
          server = find_server(args.server)
          confirm(expected: server["name"].to_s, lines: ["This command will reprovision #{server["name"]}."])
          log_id = (client.post(server_path(server, suffix: "provision")).json || {})["id"]
          queued(message: "Provisioning #{server["name"]}", log_id: log_id)
        end
      end
    end
  end
end
