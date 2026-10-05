# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      module Roles
        module Change
          include Hatchbox::Commands::Servers::Lookup

          DESTRUCTIVE_FLAG = [nil, "--confirm SERVER", "the server's name, to go ahead when it destroys data"].freeze

          def call
            server = find_server(args.server)
            wanted = args.roles.flat_map { |role| role.split(",") }.map { |role| role.strip.downcase }
            apply(server: server, roles: desired(server: server, roles: wanted))
          end

          private

          def apply(server:, roles:)
            unknown = roles - Hatchbox::ROLES
            raise Hatchbox::Error, "Unknown roles: #{unknown.join(", ")}. Roles are #{Hatchbox::ROLES.join(", ")}." if unknown.any?

            data = submit(server: server, body: { "server" => { "roles" => roles.uniq } })
            added = Array(data["added_roles"])
            removed = Array(data["removed_roles"])
            return unchanged(server) if added.empty? && removed.empty?

            message = "#{changes(added: added, removed: removed).join(" and ").sub(/\A./) { |char| char.upcase }} on #{server["name"]}"
            logs = Array(data["logs"]).map { |row| row["id"] }
            return done(message: message) if logs.empty?

            codes = logs.each_with_index.map do |id, index|
              queued(message: index.zero? ? message : "Still #{message.sub(/\A./) { |char| char.downcase }}", log_id: id)
            end
            codes.max
          end

          def submit(server:, body:)
            response = client.raw(method: "PATCH", path: server_path(server, suffix: "roles"), body: body)
            if response.code == 409 && response.json.is_a?(Hash) && response.json["destructive_changes"]
              destructive(server: server, changes: response.json["destructive_changes"])
              response = client.raw(method: "PATCH", path: server_path(server, suffix: "roles"), body: body.merge("confirm_destructive" => true))
            end
            raise Hatchbox::Error, client.error_message(response) unless response.ok?

            response.json || {}
          end

          def changes(added:, removed:)
            parts = []
            parts << "adding #{added.join(", ")}" if added.any?
            parts << "removing #{removed.join(", ")}" if removed.any?
            parts
          end

          def unchanged(server)
            puts("#{server["name"]} already has those roles.")
            0
          end

          def destructive(server:, changes:)
            roles = Array(changes["roles"])
            clusters = Array(changes["database_clusters"]).map { |row| "#{row["name"]} (#{row["engine"]})" }
            lines = ["This change destroys data on #{server["name"]}."]
            lines << "It uninstalls #{roles.join(", ")}." if roles.any?
            lines << "It destroys #{clusters.join(", ")}." if clusters.any?
            confirm(expected: server["name"].to_s, lines: lines)
          end
        end
      end
    end
  end
end
