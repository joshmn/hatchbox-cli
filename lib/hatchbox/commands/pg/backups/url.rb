# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Backups
        class Url < Hatchbox::Command
          include Hatchbox::Commands::Pg::Backups::Tools

          describe "pg:backups:url",
            summary: "get a temporary URL for the latest backup",
            usage: "pg:backups:url [DATABASE]",
            args: { database: "[DATABASE]" },
            help: ["The URL expires a few minutes after it is issued. Only S3 compatible storage can hand one out."]

          def call
            record = one_database
            data = client.get("/databases/#{record["id"]}/backups/latest").json || {}
            puts(data["url"])
            0
          end
        end
      end
    end
  end
end
