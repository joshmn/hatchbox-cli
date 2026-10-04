# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      class Kill < Hatchbox::Command
        include Hatchbox::Commands::Pg::Query

        describe("pg:kill",
          summary: "cancel a running query",
          usage: "pg:kill PID [DATABASE]",
          flags: [["-f", "--force", "terminate the connection instead of cancelling its query"]])

        def call
          usage_error("Must specify PID.") if positionals.empty?
          usage_error("Too many arguments.") if positionals.length > 2
          pid = positionals.first
          raise Hatchbox::Error, "#{pid} is not a pid. hatchbox pg:ps lists them." unless pid =~ /\A[0-9]+\z/

          function = options[:force] ? "pg_terminate_backend" : "pg_cancel_backend"
          run_sql(record: postgres(positionals[1]), sql: "SELECT #{function}(#{pid.to_i});")
        end
      end
    end
  end
end
