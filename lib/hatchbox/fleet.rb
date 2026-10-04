# frozen_string_literal: true

module Hatchbox
  class Fleet
    attr_reader :servers

    def initialize(servers:)
      @servers = servers
    end

    def active?(server)
      server["state"].to_s == "active"
    end

    def with_roles(roles)
      servers.select { |server| active?(server) && (roles_of(server) & roles).any? }.sort_by { |server| server["name"].to_s }
    end

    def app_servers
      live = servers.select { |server| active?(server) }
      coded = live.select { |server| (roles_of(server) & Hatchbox::APP_ROLES).any? }
      return coded.sort_by { |server| server["name"].to_s } if coded.any?
      return live if live.any?

      servers
    end

    def find_server(wanted)
      raise Hatchbox::Error, "That cluster has no servers." if servers.empty?
      return app_servers.first if Hatchbox.blank?(wanted)

      text = wanted.to_s.downcase
      exact = servers.find { |server| server["name"].to_s.downcase == text || server["id"].to_s == text }
      return exact if exact

      roled = app_servers.select { |server| roles_of(server).map { |role| role.downcase }.include?(text) }
      roled = servers.select { |server| roles_of(server).map { |role| role.downcase }.include?(text) } if roled.empty?
      return roled.first if roled.any?

      near = servers.select { |server| server["name"].to_s.downcase.include?(text) }
      return near.first if near.length == 1

      raise Hatchbox::Error, "No server called #{wanted}, and none with that role.\n#{listing}"
    end

    def listing
      "Servers: #{servers.map { |server| "#{server["name"]} (#{Array(server["roles"]).join(", ")})" }.join(", ")}"
    end

    def label(id)
      found = servers.find { |server| server["id"].to_s == id.to_s }
      found ? found["name"].to_s : id.to_s
    end

    private

    def roles_of(server)
      Array(server["roles"]).map { |role| role.to_s }
    end
  end
end
