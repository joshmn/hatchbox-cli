# frozen_string_literal: true

module Hatchbox
  module Commands
    module Apps
      class List < Hatchbox::Command
        describe "apps",
          summary: "list your apps",
          usage: "apps",
          aliases: ["apps:list", "list"],
          app: false,
          flags: [["-t", "--team TEAM", "only the apps on this account, by name or id"], JSON_FLAG],
          examples: ["$ hatchbox apps", "=== My Team Apps", "fpd (netcup)", "stox (purevoltage-ny)"]

        def call
          catalog = session.catalog
          accounts = Hatchbox.blank?(options.team) ? catalog.accounts : [catalog.find_account(options.team)]
          rows = catalog.entries.select { |row| accounts.any? { |account| same?(account: account, record: row[:account_record]) } }
          return print_json(rows.map { |row| row[:record].merge("account" => row[:account]) }) if json?

          clusters = cluster_names(accounts: accounts, catalog: catalog)
          shown = 0
          accounts.each do |account|
            mine = rows.select { |row| same?(account: account, record: row[:account_record]) }
            next if mine.empty?

            puts if shown.positive?
            ui.header("#{account["name"]} Apps")
            mine.each { |row| puts("#{row[:name]} (#{clusters[row[:cluster_id]] || "cluster #{row[:cluster_id]}"})") }
            shown += 1
          end
          puts("You have no apps.") if shown.zero?
          catalog.skipped.each { |name, message| ui.warning("Skipped #{name}: #{message}") if accounts.any? { |account| account["name"].to_s == name } }
          0
        end

        private

        def same?(account:, record:)
          account["id"].to_s == record["id"].to_s
        end

        def cluster_names(accounts:, catalog:)
          usable = accounts.reject { |account| catalog.skipped.key?(account["name"].to_s) }
          found = Hatchbox.parallel(usable.to_h { |account| [account["id"].to_s, -> { catalog.clusters_for(account) }] })
          found.values.flatten.to_h { |cluster| [cluster["id"].to_s, cluster["name"].to_s] }
        end
      end
    end
  end
end
