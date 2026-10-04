# frozen_string_literal: true

module Hatchbox
  module Commands
    module Firewall
      class Info < Hatchbox::Command
        include Hatchbox::Commands::Servers::Lookup

        describe("firewall:info",
          summary: "show one firewall rule",
          usage: "firewall:info SERVER RULE",
          app: :optional,
          flags: [CLUSTER_FLAG, JSON_FLAG])

        def call
          usage_error("Must specify SERVER and RULE.") unless positionals.length == 2

          server = find_server(positionals.first)
          row = client.get(server_path(server, suffix: "firewall_rules/#{positionals.last}")).json || {}
          return print_json(row) if json?

          ui.header("Rule #{row["id"]} on #{server["name"]}")
          printer.styled_hash([
            ["Port", row["port"].to_s],
            ["Action", row["action"]],
            ["From", row["from"] || "anywhere"],
            ["Description", row["description"]],
            ["Managed", row["removable"] ? "no" : "yes, by hatchbox"],
            ["Created", formatter.date(row["created_at"])]
          ])
          0
        end
      end
    end
  end
end
