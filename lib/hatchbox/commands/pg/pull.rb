# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      class Pull < Hatchbox::Command
        include Hatchbox::Commands::Pg::Tools

        describe "pg:pull",
          summary: "pull the database into a new local database",
          args: { source: "SOURCE", target: "TARGET" },
          ssh: :tunnel,
          flags: [
            [nil, "--exclude-table-data TABLES", "tables to skip the data of, separated by semicolons"],
            [nil, "--direct", "connect straight to the database host instead of through an SSH tunnel"]
          ],
          help: [
            "SOURCE is the app's database, like DATABASE_URL. TARGET is a local database name",
            "or URL, which must not exist yet; it is created with createdb. Needs pg_dump,",
            "pg_restore and createdb at least as new as the server."
          ],
          examples: ["$ hatchbox pg:pull DATABASE_URL fpd_development"]

        def call
          source = args.source
          target = args.target
          record = postgres(source)
          create(target)
          code = nil
          with_connection(record) do |database, host, port|
            ui.action("Pulling #{record["name"]} into #{target}") do |step|
              code = pipe(database: database, host: host, port: port, target: target)
              step.status = code.zero? ? "done" : ui.paint("finished with errors", code: 33)
            end
          end
          code
        end

        private

        def pipe(database:, host:, port:, target:)
          statuses = Open3.pipeline(
            [pg_environment(database: database, dangerous: false), *dump(database: database, host: host, port: port)],
            ["pg_restore", "--no-acl", "--no-owner", "-d", target]
          )
          statuses.map { |status| Hatchbox.exit_code(status) }.max
        end

        def dump(database:, host:, port:)
          argv = ["pg_dump", "-F", "c", "-Z", "0", "--no-acl", "--no-owner", "-h", host, "-p", port, "-U", database.user, "-d", database.name]
          tables = options.exclude_table_data.to_s.split(";").map { |table| table.strip }.reject { |table| table.empty? }
          argv + tables.map { |table| "--exclude-table-data=#{table}" }
        end

        def create(target)
          output, status = Open3.capture2e("createdb", target)
          return if status.success?

          raise Hatchbox::Error, "Local database #{target} already exists. Drop it first or choose another name." if output.include?("already exists")

          raise Hatchbox::Error, "createdb #{target} failed:\n#{output.strip}"
        rescue Errno::ENOENT
          raise Hatchbox::Error, "createdb is required and is not installed."
        end
      end
    end
  end
end
