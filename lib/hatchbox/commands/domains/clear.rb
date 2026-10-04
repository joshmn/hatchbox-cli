# frozen_string_literal: true

module Hatchbox
  module Commands
    module Domains
      class Clear < Hatchbox::Command
        include Hatchbox::Commands::Domains::Paths

        describe("domains:clear",
          summary: "remove every domain from the app",
          flags: [[nil, "--confirm APP", "the app's name, to skip the prompt"]])

        def call
          none!
          rows = app.domains
          return puts("#{label} has no domain names.") if rows.empty?

          names = rows.map { |row| row["name"] }.join(", ")
          confirm(expected: app.name, lines: ["This command will remove #{formatter.plural(count: rows.length, word: "domain")} from #{app.name}: #{names}."])
          ui.action("Removing all domains from #{label}") { rows.each { |row| client.delete(domain_path(row["name"].to_s)) } }
          0
        end
      end
    end
  end
end
