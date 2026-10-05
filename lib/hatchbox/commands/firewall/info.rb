# frozen_string_literal: true

module Hatchbox
  module Commands
    module Firewall
      class Info < Hatchbox::Command
        include Hatchbox::Commands::Servers::Lookup

        describe "firewall:info",
          summary: "show one firewall rule",
          args: { server: "SERVER", rule: "RULE" },
          app: :optional,
          flags: [CLUSTER_FLAG, JSON_FLAG]

        def call
          server = find_server(args.server)
          row = client.get(server_path(server, suffix: "firewall_rules/#{args.rule}")).json || {}
          return print_json(row) if json?

          ui.header("Rule #{row["id"]} on #{server["name"]}")
          printer.styled_hash([
            ["Port", row["port"].to_s],
            ["Action", row["action"]],
            ["From", row["from"] || "anywhere"],
            ["Description", row["description"]],
            ["Managed", row["removable"] ? "no" : "yes, by Hatchbox"],
            ["Created", formatter.date(row["created_at"])]
          ])
          0
        end
      end
    end
  end
end
