# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Tools
        include Hatchbox::Commands::DatabaseConnection

        private

        def postgres(wanted)
          attached(wanted, engines: ["postgresql"])
        end

        def pg_environment(database:, dangerous:)
          env = { "PGPASSWORD" => database.password, "PGSSLMODE" => database.sslmode }
          return env if dangerous

          extra = [ENV["PGOPTIONS"], "-c default_transaction_read_only=on"].reject { |part| Hatchbox.blank?(part) }
          env.merge("PGOPTIONS" => extra.join(" "))
        end

        def query(sql)
          run_sql(record: postgres(args.database), sql: sql)
        end

        def run_sql(record:, sql:)
          with_connection(record) do |database, host, port|
            argv = ["psql", "-X", "-h", host, "-p", port, "-U", database.user, "-d", database.name, "-c", sql]
            Hatchbox.run(argv, env: pg_environment(database: database, dangerous: false))
          end
        end
      end
    end
  end
end
