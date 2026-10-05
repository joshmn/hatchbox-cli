# frozen_string_literal: true

module Hatchbox
  module Commands
    module DatabaseConnection
      include Hatchbox::Commands::DatabaseLookup

      private

      def connection_text(record)
        public_uri = record["public_connection_uri"].to_s
        text = Hatchbox.blank?(public_uri) ? record["private_connection_uri"].to_s : public_uri
        raise Hatchbox::Error, "That database has no connection URI, which happens on SQLite." if Hatchbox.blank?(text)

        text
      end

      def tunnelled?(record)
        Hatchbox.blank?(record["public_connection_uri"]) && !options.key?(:direct)
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
        ui.warning("That's the private connection URI, so it only works from the servers.") if Hatchbox.blank?(record["public_connection_uri"])
        0
      end

      def statement_target(engine:, sql:)
        wanted = options.database
        return [wanted, sql] unless args.statement
        return [args.statement, sql] if app.find_database(args.statement, engines: [engine]).any? && Hatchbox.blank?(wanted)

        usage_error("Only one statement at a time. Quote it as one argument.") unless sql.empty?
        [wanted, args.statement]
      end

      def announce_session
        $stderr.puts(options.dangerous ? color.yellow("Read-write session") : color.dim("Read-only session, pass --dangerous to write"))
      end
    end
  end
end
