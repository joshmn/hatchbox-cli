# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      class Psql < Hatchbox::Command
        include Hatchbox::Commands::Pg::Tools

        describe "pg:psql",
          summary: "open a psql shell to the database",
          usage: "pg:psql [DATABASE | SQL]",
          args: { statement: "[DATABASE or SQL]" },
          ssh: :tunnel,
          aliases: ["psql"],
          flags: [
            ["-c", "--command SQL", "SQL command to run"],
            ["-f", "--file FILE", "SQL file to run"],
            ["-d", "--database NAME", "which postgresql database, when the app has more than one"],
            [nil, "--url", "print the connection URI instead of connecting"],
            [nil, "--direct", "connect straight to the database host instead of through an SSH tunnel"],
            [nil, "--dangerous", "a session that can write, which it cannot by default"]
          ],
          help: [
            "Connects to the postgresql database attached to the app. Unmanaged clusters",
            "listen on their own machine's private address, so psql goes through an SSH",
            "tunnel to the server holding the database, as the deploy user Hatchbox sets up.",
            "Sessions are read only unless you pass --dangerous. DATABASE is a database name",
            "or the config var it is attached as, like DATABASE_URL; anything else is run as",
            "SQL. psql's own flags go after --."
          ],
          examples: ["$ hatchbox pg:psql", "$ hatchbox pg:psql -c 'select count(*) from users'", "$ hatchbox pg:psql RED_DATABASE_URL --dangerous"]

        def call
          wanted, sql = statement_target(engine: "postgresql", sql: options.command.to_s.sub(/\A=/, ""))
          record = postgres(wanted)
          return print_url(record) if options.url

          open_psql(record: record, sql: sql)
        end

        private

        def open_psql(record:, sql:)
          with_connection(record) do |database, host, port|
            announce_session
            argv = ["psql", "-h", host, "-p", port, "-U", database.user, "-d", database.name]
            argv.concat(["-c", sql]) unless Hatchbox.blank?(sql)
            argv.concat(["-f", options.file]) unless Hatchbox.blank?(options.file)
            argv.concat(passthru)
            Hatchbox.run(argv, env: pg_environment(database: database, dangerous: options.dangerous))
          end
        end
      end
    end
  end
end
