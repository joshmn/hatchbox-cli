# frozen_string_literal: true

module Hatchbox
  module Commands
    module Firewall
      class Remove < Hatchbox::Command
        include Hatchbox::Commands::Servers::Lookup

        describe("firewall:remove",
          summary: "remove a firewall rule from a server",
          usage: "firewall:remove SERVER RULE",
          aliases: ["firewall:delete"],
          app: :optional,
          flags: [CLUSTER_FLAG, WAIT_FLAG],
          help: ["The rule stays in force, and listed, until ufw on the server accepts the change."])

        def call
          usage_error("Must specify SERVER and RULE.") unless positionals.length == 2

          server = find_server(positionals.first)
          log_id = (client.delete(server_path(server, suffix: "firewall_rules/#{positionals.last}")).json || {})["id"]
          queued(message: "Removing rule #{positionals.last} from #{server["name"]}", log_id: log_id)
        end
      end
    end
  end
end
