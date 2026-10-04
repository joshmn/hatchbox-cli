# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Backups
        module Tools
          include Hatchbox::Commands::DatabaseLookup

          RUN = "Servers::Databases::Backups::Run"

          private

          def backed_up(wanted)
            return attached(wanted) unless Hatchbox.blank?(wanted)

            pool = app.databases.select { |record| record["engine"] == "postgresql" }
            return pool.first if pool.length == 1

            attached(nil)
          end

          def backup_logs(record)
            client.get("/databases/#{record["id"]}/logs?limit=100").json.to_a.select { |row| row["name"] == RUN }
          end

          def one_database
            backed_up(args.database)
          end
        end
      end
    end
  end
end
