# frozen_string_literal: true

module Hatchbox
  module Commands
    module Firewall
      class List < Hatchbox::Command
        include Hatchbox::Commands::Servers::Lookup

        describe "firewall",
          summary: "list a server's firewall rules",
          args: { server: "SERVER" },
          aliases: ["firewall:list"],
          app: :optional,
          flags: [CLUSTER_FLAG, JSON_FLAG],
          help: ["Rules Hatchbox manages itself, like SSH and the web ports, cannot be removed."]

        def call
          server = find_server(args.server)
          rows = client.pages("#{server_path(server, suffix: "firewall_rules")}?limit=100").flat_map { |page| page }
          return print_json(rows) if json?

          ui.header("#{server["name"]} Firewall Rules")
          return puts("No rules.") if rows.empty?

          printer.table(rows: rows, columns: [
            ["Id", ->(row) { row["id"] }],
            ["Port", ->(row) { row["port"] }],
            ["Action", ->(row) { row["action"] == "deny" ? color.red(row["action"].to_s) : row["action"] }],
            ["From", ->(row) { row["from"] || "anywhere" }],
            ["Description", ->(row) { row["description"] }],
            ["Managed", ->(row) { row["removable"] ? "" : "Hatchbox" }]
          ])
          0
        end
      end
    end
  end
end
