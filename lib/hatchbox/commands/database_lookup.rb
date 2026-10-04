# frozen_string_literal: true

module Hatchbox
  module Commands
    module DatabaseLookup
      private

      def account
        @account ||= find_account
      end

      def find_account
        found = session.catalog.account_for(app_id)
        raise Hatchbox::Error, "Could not tell which account #{label} is on." unless found

        found
      end

      def database_clusters
        @database_clusters ||= session.catalog.database_clusters_for(account)
      end

      def database_cluster(id)
        database_clusters.find { |row| row["id"].to_s == id.to_s } || {}
      end

      def attached(wanted, engines: nil)
        pool = app.find_database(wanted, engines: engines)
        return pool.first if pool.length == 1

        kind = engines ? engines.join(" or ") : "database"
        raise Hatchbox::Error, "#{label} has more than one #{kind}, so name one:\n#{attachments_listing(pool)}" if pool.any?

        head = Hatchbox.blank?(wanted) ? "No #{kind} is attached to #{label}." : "No #{kind} called #{wanted} is attached to #{label}."
        raise Hatchbox::Error, app.databases.empty? ? head : "#{head}\n#{attachments_listing(app.databases)}"
      end

      def attachments_listing(pool)
        pool.map { |record| "#{record["name"]} (#{record["engine"]}) as #{app.attachment_names(record).join(", ")}" }.join("\n")
      end

      def title_for(record)
        names = app.attachment_names(record)
        names.empty? ? record["name"].to_s : names.join(", ")
      end

      def backup_configuration(record)
        response = client.raw(method: "GET", path: "/databases/#{record["id"]}/backup_configuration")
        return response.json if response.ok?

        { "error" => client.error_message(response) }
      end
    end
  end
end
