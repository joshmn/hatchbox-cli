# frozen_string_literal: true

module Hatchbox
  class AppCatalog
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
      accounts.reject { |account| @skipped.key?(account["name"].to_s) }
    end

    def find_account(wanted)
      Hatchbox::AccountPicker.new(accounts: accounts, usable: usable_accounts).pick(wanted)
    end

    def clusters_for(account)
      key = account["id"].to_s
      @clusters[key] ||= client.get("/accounts/#{key}/clusters").json || []
    end

    def database_clusters_for(account)
      key = account["id"].to_s
      @database_clusters[key] ||= client.get("/accounts/#{key}/database_clusters").json || []
    end

    def git_providers_for(account)
      client.get("/accounts/#{account["id"]}/git_providers").json || []
    end

    private

    attr_reader :client

    def load_apps
      return if @loaded

      @loaded = true
      jobs = accounts.to_h { |account| [account["id"].to_s, -> { client.raw(method: "GET", path: "/accounts/#{account["id"]}/apps") }] }
      Hatchbox.parallel(jobs).each do |key, response|
        account = accounts.find { |row| row["id"].to_s == key }
        if response.ok?
          @apps[key] = response.json || []
        else
          @skipped[account["name"].to_s] = client.error_message(response)
        end
      end
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
