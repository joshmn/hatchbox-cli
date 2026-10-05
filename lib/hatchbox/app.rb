# frozen_string_literal: true

module Hatchbox
  class App
    attr_reader :id, :slug

    def initialize(client:, app_id:, slug: nil)
      @client = client
      @id = app_id.to_s
      @slug = slug
    end

    def details
      @details ||= client.get("/apps/#{id}").json || {}
    end

    def name
      details["name"].to_s
    end

    def label
      from_slug = Hatchbox.slug_name(slug)
      return from_slug unless from_slug.empty?

      name.empty? ? id : name
    end

    def cluster
      @cluster ||= fetch_cluster
    end

    def servers
      cluster["servers"] || []
    end

    def processes
      @processes ||= client.get("/apps/#{id}/processes").json || []
    end

    def domains
      @domains ||= client.get("/apps/#{id}/domains").json || []
    end

    def env_var_names
      @env_var_names ||= (client.get("/apps/#{id}/env_vars").json || []).map { |row| row["name"].to_s }
    end

    def databases
      @databases ||= client.get("/apps/#{id}/databases").json || []
    end

    def fleet
      @fleet ||= Hatchbox::Fleet.new(servers: servers)
    end

    def formation
      @formation ||= Hatchbox::Formation.new(processes: processes, fleet: fleet)
    end

    def server_name(server_id)
      match = servers.find { |server| server["id"].to_s == server_id.to_s }
      return "server #{server_id}" if match.nil? || Hatchbox.blank?(match["name"])

      match["name"]
    rescue Hatchbox::Error
      "server #{server_id}"
    end

    def web_url
      found = domains.map { |row| row["name"].to_s }.reject { |host| host.start_with?("*") }.first
      found ? "https://#{found}/" : nil
    end

    def attachment_names(record)
      (record["app_attachments"] || []).select { |row| row["app_id"].to_s == id }.map { |row| row["env_var"].to_s }
    end

    def find_database(wanted, engines: nil)
      pool = databases
      pool = pool.select { |record| engines.include?(record["engine"]) } if engines
      return pool if Hatchbox.blank?(wanted)

      text = wanted.to_s
      pool.select do |record|
        record["name"].to_s == text || record["id"].to_s == text || attachment_names(record).map { |name| name.upcase }.include?(text.upcase)
      end
    end

    private

    attr_reader :client

    def fetch_cluster
      cluster_id = details["cluster_id"]
      raise Hatchbox::Error, "#{label} is not on a cluster, so there is no server to connect to." if Hatchbox.blank?(cluster_id)

      client.get("/clusters/#{cluster_id}").json || {}
    end
  end
end
