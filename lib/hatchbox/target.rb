# frozen_string_literal: true

module Hatchbox
  class Target
    attr_reader :env, :slug

    def initialize(session:)
      @session = session
    end

    def resolve
      return self if @resolved

      @resolved = true
      return by_app(session.app_flag) unless Hatchbox.blank?(session.app_flag)
      return by_remote(session.remote_flag) unless Hatchbox.blank?(session.remote_flag)
      return by_app(ENV["HATCHBOX_APP"]) unless Hatchbox.blank?(ENV["HATCHBOX_APP"])
      return by_remote(ENV["HATCHBOX_ENV"]) unless Hatchbox.blank?(ENV["HATCHBOX_ENV"])

      by_default
    end

    def app_id
      resolve
      @app_id ||= lookup
    end

    private

    attr_reader :session

    def config
      session.config
    end

    def messages
      Hatchbox::Target::Messages.new(config: config)
    end

    def by_app(value)
      text = value.to_s.strip
      match = text.match(/\A([0-9]+)(?:-(.+))?\z/)
      return by_id(text: text, id: match[1], named: !match[2].nil?) if match

      known = config.apps.select { |_env, slug| Hatchbox.slug_name(slug).casecmp?(text) }
      if known.map { |_env, slug| slug }.uniq.length == 1
        @env, @slug = known.first
        @app_id = Hatchbox.slug_id(@slug)
        return self
      end

      @wanted = text
      self
    end

    def by_id(text:, id:, named:)
      @app_id = id
      entry = config.apps.find { |_env, slug| Hatchbox.slug_id(slug) == id }
      @env = entry ? entry.first : nil
      @slug = text
      @slug = entry.last if entry && !named
      self
    end

    def by_remote(name)
      raise Hatchbox::Error, messages.no_app unless config.exists?

      found = config.app_for(name)
      raise Hatchbox::Error, "No remote named #{name} for #{config.location}.\n#{messages.remotes}" if Hatchbox.blank?(found)

      @env = name
      @slug = found
      @app_id = Hatchbox.slug_id(found)
      raise Hatchbox::Error, "#{found} for #{config.location} does not start with the app's id, the way the dashboard url spells it." if Hatchbox.blank?(@app_id)

      self
    end

    def by_default
      raise Hatchbox::Error, messages.no_app unless config.exists?

      name = config.default
      name = config.envs.first if Hatchbox.blank?(name) && config.envs.length == 1
      raise Hatchbox::Error, messages.multiple if Hatchbox.blank?(name)

      by_remote(name)
    end

    def lookup
      found = Hatchbox::App::Catalog.new(client: session.client).named(@wanted)
      raise Hatchbox::Error, "Couldn't find that app." if found.empty?
      raise Hatchbox::Error, messages.ambiguous(name: @wanted, rows: found) if found.length > 1

      @slug = found.first[:slug]
      found.first[:id]
    end
  end
end
