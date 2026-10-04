# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Query
        include Hatchbox::Commands::Pg::Tools

        private

        def query(sql, database: positionals.first)
          usage_error("One database at a time.") if positionals.length > 1

          run_sql(record: postgres(database), sql: sql)
        end
      end
    end
  end
end
