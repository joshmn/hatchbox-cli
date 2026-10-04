# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      class Ps < Hatchbox::Command
        include Hatchbox::Commands::Pg::Query

        describe "pg:ps",
          summary: "view the queries running on the database",
          usage: "pg:ps [DATABASE]",
          args: { database: "[DATABASE]" },
          ssh: :tunnel,
          flags: [["-v", "--verbose", "include idle connections"]]

        def call
          query(<<~SQL)
            SELECT
              pid,
              state,
              application_name AS source,
              usename AS username,
              age(now(), xact_start) AS running_for,
              xact_start AS transaction_start,
              wait_event IS NOT NULL AS waiting,
              query
            FROM pg_stat_activity
            WHERE query <> '<insufficient privilege>'
              #{options.verbose ? "" : "AND state <> 'idle'"}
              AND pid <> pg_backend_pid()
              AND datname = current_database()
            ORDER BY query_start DESC;
          SQL
        end
      end
    end
  end
end
