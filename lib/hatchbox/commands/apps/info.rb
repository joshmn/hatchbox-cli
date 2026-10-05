# frozen_string_literal: true

module Hatchbox
  module Commands
    module Apps
      class Info < Hatchbox::Command
        describe "apps:info",
          summary: "show detailed app information",
          args: { app: "[APP]" },
          aliases: ["info"],
          flags: [["-x", "--extended", "show the deploy scripts, the Caddyfile and the DNS settings too"], ["-s", "--shell", "output more shell friendly key/value pairs"], JSON_FLAG]

        def call
          data = gather
          return print_json(data) if json?

          details = Hatchbox::App::Details.new(data: data, formation: app.formation)
          return shell(details) if options.shell

          ui.header(data["name"])
          printer.styled_hash(details.pairs(extended: options.extended))
          0
        end

        private

        def gather
          current = app
          details = current.details
          catalog = session.catalog
          found = Hatchbox.parallel(
            cluster: -> { current.cluster },
            processes: -> { current.processes },
            domains: -> { current.domains },
            databases: -> { current.databases },
            account: -> { catalog.account_for(current.id) }
          )
          details.merge(
            "cluster" => found[:cluster].reject { |key, _value| key == "servers" },
            "servers" => found[:cluster]["servers"] || [],
            "processes" => found[:processes],
            "domains" => found[:domains].map { |row| row["name"] },
            "databases" => found[:databases].map { |record| database(record) },
            "team" => found[:account] ? found[:account]["name"] : nil,
            "git_provider" => git_provider(account: found[:account], id: details["connected_account_id"]),
            "web_url" => app.web_url
          )
        end

        def database(record)
          record.slice("id", "name", "engine", "database_cluster_id").merge("as" => app.attachment_names(record))
        end

        def git_provider(account:, id:)
          return nil if account.nil? || Hatchbox.blank?(id)

          found = session.catalog.git_providers_for(account).find { |row| row["id"].to_s == id.to_s }
          found ? "#{found["provider"]} #{found["name"]}" : "provider #{id}"
        rescue Hatchbox::Error
          "provider #{id}"
        end

        def shell(details)
          details.shell_pairs.each { |key, value| puts("#{key}=#{value}") }
          0
        end
      end
    end
  end
end
