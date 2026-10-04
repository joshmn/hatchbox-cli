# frozen_string_literal: true

module Hatchbox
  class SshTarget
    class << self
      def pinned?(session)
        return false if session.env.nil?

        !session.config.ssh(env: session.env, key: "host").nil?
      end
    end

    attr_reader :host, :user, :port, :server

    def initialize(session:, server: nil)
      @session = session
      @server = server
      @host = setting("host") || (server ? server["public_ip"].to_s : "")
      @user = setting("user") || Hatchbox::DEFAULT_SSH_USER
      @port = setting("port") || server_port
      return unless Hatchbox.blank?(host)

      raise Hatchbox::Error, "#{label} has no public IP.\n#{session.config.ssh_hint(env: session.env, key: "host")}"
    end

    def address
      "#{user}@#{host}"
    end

    def label
      return server["name"].to_s if server && !Hatchbox.blank?(server["name"])

      Hatchbox.blank?(host) ? "server" : host
    end

    def app_dir
      configured = setting("app_dir")
      return configured if configured
      return nil if app_name.empty?

      "/home/#{user}/#{app_name}/current"
    end

    def app_name
      session.app.name
    end

    def enter(separator:)
      dir = app_dir
      return "" if Hatchbox.blank?(dir)

      "cd #{Shellwords.escape(dir)} 2>/dev/null#{separator}"
    end

    def enter_or_stop
      dir = app_dir
      raise Hatchbox::Error, "No release directory to run in. #{session.config.ssh_hint(env: session.env, key: "app_dir")}" if Hatchbox.blank?(dir)

      complaint = "#{dir} is not there, so nothing is deployed yet. If the app lives somewhere else: #{session.config.ssh_hint(env: session.env, key: "app_dir")}"
      "cd #{Shellwords.escape(dir)} 2>/dev/null || { echo #{Shellwords.escape(complaint)} >&2; exit 1; }"
    end

    def ssh(command: nil, tty: false, extra: [])
      argv = ["ssh", "-p", port.to_s]
      argv.concat(Hatchbox.ssh_options)
      argv << "-t" if tty
      argv.concat(extra)
      argv << address
      argv << command if command
      argv
    end

    def login_shell(script)
      "bash -lc #{Shellwords.escape(script)}"
    end

    private

    attr_reader :session

    def setting(key)
      session.config.ssh(env: session.env, key: key)
    end

    def server_port
      return Hatchbox::DEFAULT_SSH_PORT if server.nil? || Hatchbox.blank?(server["ssh_port"])

      server["ssh_port"].to_s
    end
  end
end
