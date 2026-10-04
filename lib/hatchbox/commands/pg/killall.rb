# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      class Killall < Hatchbox::Command
        include Hatchbox::Commands::Pg::Query

        describe "pg:killall",
          summary: "terminate every other connection to the database",
          usage: "pg:killall [DATABASE]",
          args: { database: "[DATABASE]" },
          ssh: :tunnel,
          flags: [[nil, "--confirm APP", "the app's name, to skip the prompt"]],
          help: ["Only touches connections to this database, not the rest of a shared cluster."]

        def call
          record = postgres(args.database)
          confirm(expected: app.name, lines: ["This command will terminate every connection to #{record["name"]}, including #{app.name}'s own."])
          run_sql(record: record, sql: <<~SQL)
            SELECT pg_terminate_backend(pid)
            FROM pg_stat_activity
            WHERE pid <> pg_backend_pid()
              AND query <> '<insufficient privilege>'
              AND datname = current_database();
          SQL
        end
      end
    end
  end
end
