# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      class Outliers < Hatchbox::Command
        include Hatchbox::Commands::Pg::Tools

        describe "pg:outliers",
          summary: "show the queries with the longest total execution time",
          args: { database: "[DATABASE]" },
          ssh: :tunnel,
          flags: [["-n", "--num NUM", "number of queries to show, 10 unless you say otherwise", Integer], ["-t", "--truncate", "cut queries off at 40 characters"]],
          help: ["Needs the pg_stat_statements extension and PostgreSQL 13 or later."]

        def call
          shown = options.truncate ? "CASE WHEN length(query) <= 40 THEN query ELSE substr(query, 0, 39) || '...' END" : "query"
          query(<<~SQL)
            SELECT
              interval '1 millisecond' * total_exec_time AS total_exec_time,
              to_char((total_exec_time / sum(total_exec_time) OVER ()) * 100, 'FM90D0') || '%' AS prop_exec_time,
              to_char(calls, 'FM999G999G999G990') AS ncalls,
              #{shown} AS query
            FROM pg_stat_statements
            WHERE userid = (SELECT usesysid FROM pg_user WHERE usename = current_user LIMIT 1)
            ORDER BY total_exec_time DESC
            LIMIT #{(options.num || 10).to_i};
          SQL
        end
      end
    end
  end
end
