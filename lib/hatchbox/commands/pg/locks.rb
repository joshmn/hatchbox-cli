# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      class Locks < Hatchbox::Command
        include Hatchbox::Commands::Pg::Tools

        describe "pg:locks",
          summary: "display queries with active locks",
          args: { database: "[DATABASE]" },
          ssh: :tunnel

        def call
          query(<<~SQL)
            SELECT
              pg_stat_activity.pid,
              pg_class.relname,
              pg_locks.transactionid,
              pg_locks.granted,
              pg_stat_activity.query AS query_snippet,
              age(now(), pg_stat_activity.query_start) AS "age"
            FROM pg_stat_activity, pg_locks
            LEFT OUTER JOIN pg_class ON (pg_locks.relation = pg_class.oid)
            WHERE pg_stat_activity.query <> '<insufficient privilege>'
              AND pg_locks.pid = pg_stat_activity.pid
              AND pg_locks.mode = 'ExclusiveLock'
              AND pg_stat_activity.pid <> pg_backend_pid()
            ORDER BY query_start;
          SQL
        end
      end
    end
  end
end
