# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Query
        include Hatchbox::Commands::Pg::Tools

        private

        def query(sql, database: args.database)
          run_sql(record: postgres(database), sql: sql)
        end
      end
    end
  end
end
