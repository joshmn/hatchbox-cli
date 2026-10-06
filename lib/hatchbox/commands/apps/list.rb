# frozen_string_literal: true

module Hatchbox
  module Commands
    module Apps
      class List < Hatchbox::Command
        describe "apps",
          summary: "list your apps",
          aliases: ["apps:list", "list"],
          app: false,
          flags: [["-t", "--team TEAM", "only the apps on this account, by name or id"], JSON_FLAG],
          examples: ["$ hatchbox apps", "=== My Team Apps", "fpd (netcup)", "stox (purevoltage-ny)"]

        def call
          catalog = session.catalog
          accounts = Hatchbox.blank?(options.team) ? catalog.accounts : [catalog.find_account(options.team)]
          grouped = catalog.entries.group_by { |row| row[:account_record]["id"].to_s }
          groups = accounts.map { |account| [account, grouped.fetch(account["id"].to_s, [])] }.reject { |_account, rows| rows.empty? }
          return print_json(groups.flat_map { |_account, rows| rows.map { |row| row[:record].merge("account" => row[:account]) } }) if json?

          clusters = cluster_names(accounts: accounts, catalog: catalog)
          groups.each_with_index do |(account, rows), index|
            puts if index.positive?
            ui.header("#{account["name"]} Apps")
            rows.each { |row| puts("#{row[:name]} (#{clusters[row[:cluster_id]] || "cluster #{row[:cluster_id]}"})") }
          end
          puts("You have no apps.") if groups.empty?
          accounts.each do |account|
            message = catalog.skipped[account["id"].to_s]
            ui.warning("Skipped #{account["name"]}: #{message}") if message
          end
          0
        end

        private

        def cluster_names(accounts:, catalog:)
          usable = accounts.reject { |account| catalog.skipped.key?(account["id"].to_s) }
          found = Hatchbox.parallel(usable.to_h { |account| [account["id"].to_s, -> { catalog.clusters_for(account) }] })
          found.values.flatten.to_h { |cluster| [cluster["id"].to_s, cluster["name"].to_s] }
        end
      end
    end
  end
end
