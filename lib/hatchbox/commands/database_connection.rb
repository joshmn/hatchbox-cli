# frozen_string_literal: true

module Hatchbox
  module Commands
    module DatabaseConnection
      include Hatchbox::Commands::DatabaseLookup

      private

      def connection_text(record)
        public_uri = record["public_connection_uri"].to_s
        text = Hatchbox.blank?(public_uri) ? record["private_connection_uri"].to_s : public_uri
        raise Hatchbox::Error, "That database has no connection URI, which happens on sqlite." if Hatchbox.blank?(text)

        text
      end

      def tunnelled?(record)
        Hatchbox.blank?(record["public_connection_uri"]) && !options[:direct]
      end

      def with_connection(record, role: "postgresql")
        database = Hatchbox::Database.new(connection_text(record))
        tunnel = tunnelled?(record) ? Hatchbox::Tunnel.open(session: session, host: database.host, port: database.port, role: role) : nil
        host = tunnel ? "127.0.0.1" : database.host
        port = tunnel ? tunnel.local_port.to_s : database.port
        begin
          yield(database, host, port)
        ensure
          tunnel.close if tunnel
        end
      end

      def print_url(record)
        puts(connection_text(record))
        ui.warning("That host is the database's own machine, so the URI only works from the servers.") if Hatchbox.blank?(record["public_connection_uri"])
        0
      end
    end
  end
end
