# frozen_string_literal: true

module Hatchbox
  module Commands
    module Git
      class Providers < Hatchbox::Command
        describe("git:providers",
          summary: "list the connected git accounts apps can deploy from",
          app: false,
          flags: [["-t", "--team TEAM", "only this account, by name or id"], JSON_FLAG])

        def call
          none!
          catalog = session.catalog
          accounts = Hatchbox.blank?(options[:team]) ? catalog.usable_accounts : [catalog.find_account(options[:team])]
          found = accounts.to_h { |account| [account, catalog.git_providers_for(account)] }
          return print_json(found.values.flatten) if json?

          found.each_with_index do |(account, rows), index|
            puts if index.positive?
            ui.header("#{account["name"]} Git Providers")
            next puts("None connected.") if rows.empty?

            printer.table(rows: rows, columns: [["Provider", ->(row) { row["provider"] }], ["Name", ->(row) { row["name"] }], ["Id", ->(row) { row["id"] }]])
          end
          0
        end
      end
    end
  end
end
