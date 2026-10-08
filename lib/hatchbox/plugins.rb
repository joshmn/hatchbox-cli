# frozen_string_literal: true

module Hatchbox
  module Plugins
    class << self
      def load(store: Hatchbox::Store.new)
        return if @loaded

        @loaded = true
        return unless Hatchbox.blank?(ENV["HATCHBOX_NO_PLUGINS"])

        wanted(store).each do |name|
          require_plugin(name)
        rescue Hatchbox::Error => e
          Hatchbox::Ui.warning(e.message)
        end
        Hatchbox::Registry.conflicts.each { |message| Hatchbox::Ui.warning(message) }
      end

      def require_plugin(name)
        Hatchbox::Registry.loading(name) { Kernel.require(entry_point(name)) }
      rescue Gem::MissingSpecError
        Hatchbox::Registry.drop(name)
        raise Hatchbox::Error, "The #{name} plugin isn't installed. hatchbox plugins:install #{name} installs it."
      rescue ScriptError, StandardError => e
        Hatchbox::Registry.drop(name)
        raise Hatchbox::Error, "Couldn't load the #{name} plugin: #{e.message}"
      end

      def saved(store)
        Array(store.data["plugins"]).select { |name| name.is_a?(String) }
      end

      def save(name:, store:)
        store.update { |data| data["plugins"] = (Array(data["plugins"]) + [name]).uniq }
      end

      def forget(name:, store:)
        store.update do |data|
          data["plugins"] = Array(data["plugins"]) - [name]
          data.delete("plugins") if data["plugins"].empty?
        end
      end

      def path?(name)
        name.start_with?("/", "~", ".")
      end

      def bundled?
        return false unless defined?(Bundler)

        !Hatchbox.blank?(ENV["BUNDLE_GEMFILE"])
      end

      private

      def wanted(store)
        (saved(store) + from_env).uniq
      rescue Hatchbox::Error => e
        Hatchbox::Ui.warning("Skipped the plugins saved in #{store.display_path}. #{e.message}")
        from_env
      end

      def from_env
        ENV["HATCHBOX_PLUGINS"].to_s.split(",").map { |name| name.strip }.reject { |name| name.empty? }
      end

      def entry_point(name)
        return File.expand_path(name) if path?(name)

        gem(name)
        Gem.loaded_specs[name].metadata.fetch("hatchbox_plugin", name)
      end
    end
  end
end
