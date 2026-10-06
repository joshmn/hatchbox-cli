# frozen_string_literal: true

module Hatchbox
  class App
    class Catalog
      def initialize(client:)
        @client = client
        @apps = {}
        @skipped = {}
        @clusters = {}
        @database_clusters = {}
      end

      def accounts
        @accounts ||= client.get("/accounts").json || []
      end

      def entries(filter: nil)
        load_apps
        rows = accounts.flat_map do |account|
          (@apps[account["id"].to_s] || []).map { |app| entry(account: account, app: app) }
        end
        return rows if Hatchbox.blank?(filter)

        wanted = filter.downcase
        rows.select { |row| row[:slug].downcase.include?(wanted) || row[:name].downcase.include?(wanted) }
      end

      def named(name)
        entries.select { |row| row[:name].casecmp?(name.to_s) }
      end

      def account_for(app_id)
        found = entries.find { |row| row[:id] == app_id.to_s }
        found ? found[:account_record] : nil
      end

      def skipped
        load_apps
        @skipped
      end

      def usable_accounts
        load_apps
        accounts.reject { |account| @skipped.key?(account["id"].to_s) }
      end

      def find_account(wanted)
        return only_usable_account if Hatchbox.blank?(wanted)

        text = wanted.to_s
        found = accounts.find { |account| [account["id"].to_s, "acct_#{account["id"]}"].include?(text) || account["name"].to_s.casecmp?(text) }
        raise Hatchbox::Error, "Couldn't find that team." unless found

        found
      end

      def clusters_for(account)
        key = account["id"].to_s
        @clusters[key] ||= client.get("/accounts/#{key}/clusters").json || []
      end

      def find_cluster(wanted, accounts:)
        text = wanted.to_s
        accounts.flat_map { |account| clusters_for(account) }.find { |row| row["id"].to_s == text || row["name"].to_s.casecmp?(text) }
      end

      def database_clusters_for(account)
        key = account["id"].to_s
        @database_clusters[key] ||= client.get("/accounts/#{key}/database_clusters").json || []
      end

      def git_providers_for(account)
        client.get("/accounts/#{account["id"]}/git_providers").json || []
      end

      def find_git_provider(wanted, account:)
        text = wanted.to_s
        providers = git_providers_for(account)
        found = providers.select { |row| row["id"].to_s == text || row["name"].to_s.casecmp?(text) || "#{row["provider"]}:#{row["name"]}".casecmp?(text) }
        return found.first if found.length == 1

        listing = providers.map { |row| "#{row["provider"]}:#{row["name"]} (#{row["id"]})" }
        raise Hatchbox::Error, (["More than one git provider is called #{wanted}. Use provider:name or the id:"] + listing).join("\n") if found.length > 1

        raise Hatchbox::Error, (["No git provider called #{wanted}. Providers:"] + listing).join("\n")
      end

      private

      attr_reader :client

      def load_apps
        return if @loaded

        @loaded = true
        jobs = accounts.to_h { |account| [account["id"].to_s, -> { client.raw(method: "GET", path: "/accounts/#{account["id"]}/apps") }] }
        Hatchbox.parallel(jobs).each do |key, response|
          if response.ok?
            @apps[key] = response.json || []
          else
            @skipped[key] = client.error_message(response)
          end
        end
      end

      def only_usable_account
        usable = usable_accounts
        return usable.first if usable.length == 1
        raise Hatchbox::Error, "This token could not list the apps in any of its accounts. hatchbox apps shows each account it skipped and why." if usable.empty?

        raise Hatchbox::Error, (["Pick an account with --team:"] + usable.map { |account| "#{account["name"]} (#{account["id"]})" }).join("\n")
      end

      def entry(account:, app:)
        {
          id: app["id"].to_s,
          name: app["name"].to_s,
          slug: "#{app["id"]}-#{app["name"]}",
          cluster_id: app["cluster_id"].to_s,
          account: account["name"].to_s,
          account_record: account,
          record: app
        }
      end
    end
  end
end
