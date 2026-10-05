# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      class Activity < Hatchbox::Command
        include Hatchbox::Commands::Servers::Lookup

        describe "servers:activity",
          summary: "list what Hatchbox has done to a server",
          args: { server: "SERVER" },
          app: :optional,
          flags: [CLUSTER_FLAG, ["-n", "--num NUM", "number of entries", Integer], [nil, "--all", "include the per-server output of app deploys"], JSON_FLAG]

        def call
          server = find_server(args.server)
          count = options.num || 20
          rows = client.get("#{server_path(server, suffix: "logs")}?limit=#{options.all ? count : 100}").json || []
          rows = rows.select { |row| row["parent_id"].nil? }.first(count) unless options.all
          return print_json(rows) if json?

          ui.header("#{server["name"]} Activity")
          return puts("Nothing on record.") if rows.empty?

          printer.columns(Hatchbox::Activity.rows(rows))
          0
        end
      end
    end
  end
end
