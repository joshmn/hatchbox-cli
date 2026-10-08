# frozen_string_literal: true

module Hatchbox
  module Commands
    module Plugins
      class Install < Hatchbox::Command
        GEM_NAME = /\A[A-Za-z0-9._-]+\z/.freeze

        describe "plugins:install",
          summary: "install a plugin and load it on every run",
          args: { plugin: "PLUGIN" },
          app: false,
          help: [
            "PLUGIN is a gem name or a path to a Ruby file. A gem that isn't installed yet gets",
            "installed into the Ruby running hatchbox. It only goes in the plugins list in",
            "~/.hatchbox once it loads and adds at least one command. hatchbox",
            "plugins:uninstall takes it back out."
          ],
          examples: [
            "$ hatchbox plugins:install hatchbox-acme",
            "Installing hatchbox-acme... done",
            "hatchbox-acme adds acme:secrets and acme:sync",
            "",
            "$ hatchbox plugins:install ./script/hatchbox_commands.rb"
          ]

        def call
          name = Hatchbox::Plugins.path?(args.plugin) ? File.expand_path(args.plugin) : args.plugin
          store = Hatchbox::Store.new
          return already(name) if Hatchbox::Plugins.saved(store).include?(name)

          Hatchbox::Plugins.path?(name) ? check_file(name) : install_gem(name)
          Hatchbox::Plugins.require_plugin(name)
          added = Hatchbox::Registry.from(name)
          raise Hatchbox::Error, "#{name} loaded, but it didn't add any commands. A plugin that uses Zeitwerk has to eager load its command classes." if added.empty?

          Hatchbox::Registry.conflicts(name).each { |message| ui.warning(message) }
          Hatchbox::Plugins.save(name: name, store: store)
          puts("#{Hatchbox.tilde(name)} adds #{formatter.list(added)}")
          0
        end

        private

        def already(name)
          puts("#{Hatchbox.tilde(name)} is already installed.")
          0
        end

        def check_file(path)
          return if File.file?(path) || File.file?("#{path}.rb")

          raise Hatchbox::Error, "No file at #{Hatchbox.tilde(path)}."
        end

        def install_gem(name)
          usage_error("#{name} isn't a gem name or a path.") unless name.match?(GEM_NAME)
          return if Gem::Specification.find_all_by_name(name).any?
          raise Hatchbox::Error, "hatchbox is running under Bundler, so add #{name} to your Gemfile instead." if Hatchbox::Plugins.bundled?

          ui.action("Installing #{name}") { Gem.install(name, Gem::Requirement.default, document: []) }
        rescue Gem::UnsatisfiableDependencyError => e
          raise Hatchbox::Error, "There's no gem called #{name}." if e.name == name

          raise Hatchbox::Error, "Couldn't install #{name}: #{e.message}"
        rescue Gem::Exception => e
          raise Hatchbox::Error, "Couldn't install #{name}: #{e.message}\nInstall it with gem install #{name}, then run this again."
        end
      end
    end
  end
end
