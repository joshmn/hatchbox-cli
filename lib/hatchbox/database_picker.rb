# frozen_string_literal: true

module Hatchbox
  class DatabasePicker
    def initialize(session:, role: "postgresql")
      @session = session
      @role = role
    end

    def pick
      servers = session.app.servers
      found = servers.find { |server| (server["roles"] || []).include?(role) }
      found = servers.first if found.nil? && servers.length == 1
      raise Hatchbox::Error, "Could not tell which server holds the database. Set ssh_host:#{session.env || "ENV"} in #{session.config.path}." unless found

      found
    end

    private

    attr_reader :session, :role
  end
end
