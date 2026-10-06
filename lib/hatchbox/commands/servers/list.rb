# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      class List < Hatchbox::Command
        include Hatchbox::Commands::Servers::Lookup

        describe "servers",
          summary: "list the servers in the app's cluster",
          aliases: ["servers:list"],
          flags: [CLUSTER_FLAG, JSON_FLAG]

        def call
          servers = cluster_record["servers"] || []
          return print_json(servers) if json?

          ui.header("#{cluster_record["name"]} Servers")
          return puts("No servers.") if servers.empty?

          printer.table(rows: servers, columns: [
            ["Name", ->(row) { row["name"] }],
            ["Id", ->(row) { row["id"] }],
            ["State", ->(row) { row["state"] == "active" ? row["state"] : color.yellow(row["state"].to_s) }],
            ["Roles", ->(row) { Array(row["roles"]).join(", ") }],
            ["Public IP", ->(row) { row["public_ip"] }],
            ["Private IP", ->(row) { row["private_ip"] }],
            ["Size", ->(row) { row["size"] }],
            ["OS", ->(row) { row["ubuntu_version"] }]
          ])
          0
        end
      end
    end
  end
end
