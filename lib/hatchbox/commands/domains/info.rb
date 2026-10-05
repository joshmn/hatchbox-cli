# frozen_string_literal: true

module Hatchbox
  module Commands
    module Domains
      class Info < Hatchbox::Command
        include Hatchbox::Commands::Domains::Paths

        describe "domains:info",
          summary: "show one of the app's domains",
          args: { hostname: "HOSTNAME" },
          flags: [JSON_FLAG]

        def call
          name = args.hostname
          row = client.get(domain_path(name)).json || {}
          return print_json(row) if json?

          ui.header(row["name"].to_s)
          printer.styled_hash([
            ["Id", row["id"].to_s],
            ["Created", formatter.date(row["created_at"])],
            ["Updated", formatter.date(row["updated_at"])],
            ["Server IPs", targets]
          ])
          0
        end
      end
    end
  end
end
