# frozen_string_literal: true

module Hatchbox
  module Commands
    module Mysql
      class Cli < Hatchbox::Command
        include Hatchbox::Commands::DatabaseConnection

        describe "mysql:cli",
          summary: "open a mysql shell to the app's MySQL database",
          usage: "mysql:cli [DATABASE | SQL]",
          args: { statement: "[DATABASE or SQL]" },
          ssh: :tunnel,
          aliases: ["mysql"],
          flags: [
            ["-c", "--command SQL", "SQL statement to run"],
            ["-d", "--database NAME", "which MySQL database, when the app has more than one"],
            [nil, "--url", "print the connection URI instead of connecting"],
            [nil, "--direct", "connect straight to the database host instead of through an SSH tunnel"],
            [nil, "--dangerous", "a session that can write, which it cannot by default"]
          ],
          help: [
            "Sessions start with SET SESSION TRANSACTION READ ONLY unless you pass",
            "--dangerous. The password goes in a temporary option file, so it stays out of",
            "the process list. DATABASE is a database name or the config var it is attached",
            "as; anything else is run as SQL. mysql's own flags go after --."
          ],
          examples: ["$ hatchbox mysql:cli", "$ hatchbox mysql:cli -c 'select count(*) from users'"]

        def call
          wanted, sql = statement_target(engine: "mysql", sql: options.command.to_s.sub(/\A=/, ""))
          record = attached(wanted, engines: ["mysql"])
          return print_url(record) if options.url

          open_mysql(record: record, sql: sql)
        end

        private

        def open_mysql(record:, sql:)
          with_connection(record, role: "mysql") do |database, host, port|
            announce_session
            Dir.mktmpdir("hbx") do |dir|
              defaults = File.join(dir, "my.cnf")
              write_defaults(path: defaults, password: database.password)
              Hatchbox.run(mysql_command(database: database, host: host, port: port, defaults: defaults, sql: sql))
            end
          end
        end

        def write_defaults(path:, password:)
          File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
            file.puts("[client]")
            file.puts("password=\"#{password.gsub("\\", "\\\\\\\\").gsub("\"", "\\\\\"")}\"")
          end
        end

        def mysql_command(database:, host:, port:, defaults:, sql:)
          argv = ["mysql", "--defaults-extra-file=#{defaults}", "-h", host, "-P", port, "-u", database.user]
          argv << "--ssl-mode=REQUIRED" if database.sslmode.start_with?("require", "verify")
          argv << "--init-command=SET SESSION TRANSACTION READ ONLY" unless options.dangerous
          argv.concat(["-e", sql]) unless Hatchbox.blank?(sql)
          argv.concat(passthru)
          argv << database.name unless database.name.empty?
          argv
        end
      end
    end
  end
end
