# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      class Kill < Hatchbox::Command
        include Hatchbox::Commands::Pg::Tools

        describe "pg:kill",
          summary: "cancel a running query",
          args: { pid: "PID", database: "[DATABASE]" },
          ssh: :tunnel,
          flags: [["-f", "--force", "terminate the connection instead of canceling its query"]]

        def call
          pid = args.pid
          raise Hatchbox::Error, "#{pid} is not a pid. hatchbox pg:ps lists them." unless pid =~ /\A[0-9]+\z/

          function = options.force ? "pg_terminate_backend" : "pg_cancel_backend"
          run_sql(record: postgres(args.database), sql: "SELECT #{function}(#{pid.to_i});")
        end
      end
    end
  end
end
