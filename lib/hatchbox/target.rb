# frozen_string_literal: true

module Hatchbox
  class Target
    attr_reader :remote, :slug

    def initialize(session:)
      @session = session
    end

    def resolve
      return by_app(session.app_flag) unless Hatchbox.blank?(session.app_flag)
      return by_remote(session.remote_flag) unless Hatchbox.blank?(session.remote_flag)
      return by_app(ENV["HATCHBOX_APP"]) unless Hatchbox.blank?(ENV["HATCHBOX_APP"])
      return by_remote(ENV["HATCHBOX_REMOTE"]) unless Hatchbox.blank?(ENV["HATCHBOX_REMOTE"])

      by_default
    end

    def app_id
      @app_id ||= lookup
    end

    private

    attr_reader :session

    def config
      session.config
    end

    def by_app(value)
      text = value.to_s.strip
      match = text.match(/\A([0-9]+)(?:-(.+))?\z/)
      return by_id(text: text, id: match[1], named: !match[2].nil?) if match

      known = config.apps.select { |_remote, slug| Hatchbox.slug_name(slug).casecmp?(text) }
      if known.map { |_remote, slug| slug }.uniq.length == 1
        @remote, @slug = known.first
        @app_id = Hatchbox.slug_id(@slug)
        return self
      end

      @wanted = text
      self
    end

    def by_id(text:, id:, named:)
      @app_id = id
      entry = config.apps.find { |_remote, slug| Hatchbox.slug_id(slug) == id }
      @remote = entry ? entry.first : nil
      @slug = text
      @slug = entry.last if entry && !named
      self
    end

    def by_remote(name)
      raise Hatchbox::Error, no_app_message unless config.exists?

      found = config.app_for(name)
      raise Hatchbox::Error, "No remote named #{name} for #{config.location}.\n#{remotes_message}" if Hatchbox.blank?(found)

      @remote = name
      @slug = found
      @app_id = Hatchbox.slug_id(found)
      raise Hatchbox::Error, "#{found} for #{config.location} does not start with the app's id. Use the id-name form from the app's dashboard URL." if Hatchbox.blank?(@app_id)

      self
    end

    def by_default
      raise Hatchbox::Error, no_app_message unless config.exists?

      name = config.default
      name = config.remotes.first if Hatchbox.blank?(name) && config.remotes.length == 1
      raise Hatchbox::Error, multiple_message if Hatchbox.blank?(name)

      by_remote(name)
    end

    def lookup
      found = Hatchbox::App::Catalog.new(client: session.client).named(@wanted)
      raise Hatchbox::Error, "Couldn't find that app." if found.empty?
      raise Hatchbox::Error, ambiguous_message(name: @wanted, rows: found) if found.length > 1

      @slug = found.first[:slug]
      found.first[:id]
    end

    def no_app_message
      "No app specified.\nSave a remote for this repo with hatchbox git:remote, or specify which app to use with --app APP."
    end

    def multiple_message
      first_remote, first_app = config.apps.first
      [
        "Multiple remotes for #{config.location}, and none is the default",
        "Usage: --remote #{first_remote}",
        "   or: --app #{first_app}",
        "Or set \"default\": \"#{first_remote}\" for this repo in ~/.hatchbox.",
        "Remotes:"
      ].concat(config.apps.map { |remote, slug| "#{slug} (#{remote})" }).join("\n")
    end

    def remotes_message
      return "This project has no remotes yet. Add one with hatchbox git:remote -a APP." if config.remotes.empty?

      "Remotes: #{config.remotes.join(", ")}"
    end

    def ambiguous_message(name:, rows:)
      (["There is more than one app named #{name}. Pass one of these to --app:"] + rows.map { |row| "#{row[:slug]} (#{row[:account]})" }).join("\n")
    end
  end
end
