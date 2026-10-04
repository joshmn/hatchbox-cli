# frozen_string_literal: true

module Hatchbox
  module Commands
    module Domains
      class List < Hatchbox::Command
        describe "domains",
          summary: "list the app's domains",
          flags: [JSON_FLAG]

        def call
          rows = app.domains
          return print_json(rows) if json?

          ui.header("#{label} Custom Domains")
          return puts("#{label} has no domain names.") if rows.empty?

          printer.table(rows: rows, columns: [["Domain Name", ->(row) { row["name"] }], ["Created", ->(row) { formatter.short_date(row["created_at"]) }]])
          0
        end
      end
    end
  end
end
