# frozen_string_literal: true

module Hatchbox
  class Session
    attr_reader :app_flag, :remote_flag

    def initialize(app_flag: nil, remote_flag: nil)
      @app_flag = app_flag
      @remote_flag = remote_flag
    end

    def config
      @config ||= Hatchbox::Config.new(Hatchbox::ConfigLocator.find || File.join(Dir.pwd, ".hatchbox"))
    end

    def target
      @target ||= Hatchbox::Target.new(session: self).resolve
    end

    def env
      target.env
    end

    def app_id
      target.app_id
    end

    def token
      @token ||= find_token
    end

    def client
      @client ||= Hatchbox::Client.new(token: token)
    end

    def app
      @app ||= Hatchbox::App.new(client: client, app_id: app_id, slug: target.slug)
    end

    def catalog
      @catalog ||= Hatchbox::AppCatalog.new(client: client)
    end

    def prompt
      @prompt ||= Hatchbox::Prompt.new
    end

    private

    def find_token
      scope = @target ? @target.env : remote_flag
      found = Hatchbox::TokenStore.new.read(env: scope)
      raise Hatchbox::Error, "Not logged in.\nRun hatchbox login, or set HATCHBOX_API_TOKEN." if Hatchbox.blank?(found)

      found
    end
  end
end
