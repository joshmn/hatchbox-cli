# frozen_string_literal: true

module Hatchbox
  module Commands
    module Firewall
      class Remove < Hatchbox::Command
        include Hatchbox::Commands::Servers::Lookup

        describe "firewall:remove",
          summary: "remove a firewall rule from a server",
          args: { server: "SERVER", rule: "RULE" },
          aliases: ["firewall:delete"],
          app: :optional,
          flags: [CLUSTER_FLAG, WAIT_FLAG]

        def call
          server = find_server(args.server)
          log_id = (client.delete(server_path(server, suffix: "firewall_rules/#{args.rule}")).json || {})["id"]
          queued(message: "Removing rule #{args.rule} from #{server["name"]}", log_id: log_id)
        end
      end
    end
  end
end
