# frozen_string_literal: true

module Hatchbox
  class Tunnel
    class << self
      def open(session:, host:, port:, role:)
        new(session: session, host: host, port: port, role: role).open
      end
    end

    attr_reader :local_port

    def initialize(session:, host:, port:, role:)
      @session = session
      @host = host
      @port = port
      @role = role
    end

    def open
      @target = Hatchbox::SshTarget.for(session) { database_server }
      @local_port = free_port
      @dir = Dir.mktmpdir("hbx", "/tmp")
      Hatchbox::Ui.note("Tunneling to #{host}:#{port} through #{target.address}")
      raise Hatchbox::Error, failure_message unless Hatchbox.run(ssh_command).zero?

      self
    end

    def close
      Hatchbox.run(["ssh", "-S", control, "-O", "exit", "-o", "LogLevel=QUIET", target.address])
      FileUtils.remove_entry(dir)
    end

    private

    attr_reader :session, :host, :port, :role, :dir, :target

    def database_server
      found = session.app.fleet.holding(role)
      raise Hatchbox::Error, "Could not tell which server holds the database. #{session.config.ssh_hint(remote: session.remote, key: "host")}" unless found

      found
    end

    def control
      File.join(dir, "control")
    end

    def ssh_command
      argv = ["ssh", "-f", "-N", "-M", "-S", control, "-o", "ExitOnForwardFailure=yes", "-o", "ConnectTimeout=10", "-p", target.port.to_s]
      argv.concat(Hatchbox.ssh_options)
      argv.concat(["-L", "127.0.0.1:#{local_port}:#{host}:#{port}", target.address])
    end

    def failure_message
      "Could not open an SSH tunnel. Hatchbox puts your key on the deploy user, so\n" \
        "check that ssh #{target.address} works. #{session.config.ssh_hint(remote: session.remote, key: "user")}"
    end

    def free_port
      socket = TCPServer.new("127.0.0.1", 0)
      picked = socket.addr[1]
      socket.close
      picked
    end
  end
end
