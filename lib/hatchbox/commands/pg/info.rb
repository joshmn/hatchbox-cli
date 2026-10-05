# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      class Info < Hatchbox::Command
        include Hatchbox::Commands::Pg::Tools

        describe "pg:info",
          summary: "show database information",
          args: { database: "[DATABASE]" },
          aliases: ["pg"]

        def call
          pool = args.database.nil? ? app.databases.select { |record| record["engine"] == "postgresql" } : [postgres(args.database)]
          return puts("#{label} has no postgresql databases.") if pool.empty?

          pool.each_with_index do |record, index|
            puts if index.positive?
            show(record)
          end
          0
        end

        private

        def show(record)
          cluster = database_cluster(record["database_cluster_id"])
          ui.header(title_for(record))
          printer.styled_hash([
            ["Database", record["name"]],
            ["Cluster", cluster["name"]],
            ["PG Version", cluster["version"]],
            ["Managed", flag(cluster: cluster, key: "managed", on: "yes", off: "no")],
            ["Region", cluster["region"]],
            ["Status", flag(cluster: cluster, key: "active", on: "Available", off: "Provisioning")],
            ["Backups", cluster["managed"] ? "handled by your provider" : Hatchbox::BackupSchedule.line(backup_configuration(record))]
          ])
        end

        def flag(cluster:, key:, on:, off:)
          return nil unless cluster.key?(key)

          cluster[key] ? on : off
        end
      end
    end
  end
end
