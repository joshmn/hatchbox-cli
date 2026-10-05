# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      class Blocking < Hatchbox::Command
        include Hatchbox::Commands::Pg::Tools

        describe "pg:blocking",
          summary: "display queries holding locks other queries are waiting to be released",
          args: { database: "[DATABASE]" },
          ssh: :tunnel

        def call
          query(<<~SQL)
            SELECT
              bl.pid AS blocked_pid,
              ka.query AS blocking_statement,
              now() - ka.query_start AS blocking_duration,
              kl.pid AS blocking_pid,
              a.query AS blocked_statement,
              now() - a.query_start AS blocked_duration
            FROM pg_catalog.pg_locks bl
            JOIN pg_catalog.pg_stat_activity a ON bl.pid = a.pid
            JOIN pg_catalog.pg_locks kl
              JOIN pg_catalog.pg_stat_activity ka ON kl.pid = ka.pid
            ON bl.transactionid = kl.transactionid AND bl.pid != kl.pid
            WHERE NOT bl.granted;
          SQL
        end
      end
    end
  end
end
