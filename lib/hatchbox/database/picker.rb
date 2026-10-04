# frozen_string_literal: true

module Hatchbox
  class Database
    class Picker
      def initialize(session:, role: "postgresql")
        @session = session
        @role = role
      end

      def pick
        servers = session.app.servers
        found = servers.find { |server| (server["roles"] || []).include?(role) }
        found = servers.first if found.nil? && servers.length == 1
        raise Hatchbox::Error, "Could not tell which server holds the database. #{session.config.ssh_hint(env: session.env, key: "host")}" unless found

        found
      end

      private

      attr_reader :session, :role
    end
  end
end
