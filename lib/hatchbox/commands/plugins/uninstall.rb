# frozen_string_literal: true

module Hatchbox
  module Commands
    module Plugins
      class Uninstall < Hatchbox::Command
        describe "plugins:uninstall",
          summary: "stop loading a plugin and uninstall its gem",
          args: { plugin: "PLUGIN" },
          app: false,
          help: [
            "PLUGIN is a gem name or a path, the same way it went in with plugins:install.",
            "A gem plugin's gem gets uninstalled too, every version of it, unless another gem",
            "depends on it or hatchbox is running under Bundler. A file plugin's file is left",
            "where it is."
          ],
          examples: [
            "$ hatchbox plugins:uninstall hatchbox-acme",
            "Removing hatchbox-acme from ~/.hatchbox... done",
            "Uninstalling the hatchbox-acme gem... done"
          ]

        def call
          name = Hatchbox::Plugins.path?(args.plugin) ? File.expand_path(args.plugin) : args.plugin
          store = Hatchbox::Store.new
          saved = Hatchbox::Plugins.saved(store)
          raise Hatchbox::Error, not_installed(name: name, saved: saved) unless saved.include?(name)

          ui.action("Removing #{Hatchbox.tilde(name)} from #{store.display_path}") { Hatchbox::Plugins.forget(name: name, store: store) }
          return 0 if Hatchbox::Plugins.path?(name)
          return bundled(name) if Hatchbox::Plugins.bundled?

          uninstall_gem(name)
        end

        private

        def not_installed(name:, saved:)
          return "#{Hatchbox.tilde(name)} isn't installed, and neither is any other plugin." if saved.empty?

          "#{Hatchbox.tilde(name)} isn't installed.\nInstalled plugins: #{saved.map { |entry| Hatchbox.tilde(entry) }.join(", ")}"
        end

        def bundled(name)
          ui.warning("hatchbox is running under Bundler, so take #{name} out of your Gemfile too.")
          0
        end

        def uninstall_gem(name)
          return 0 unless removable?(name)

          Kernel.require("rubygems/uninstaller")
          uninstaller = Gem::Uninstaller.new(name, all: true, executables: true, abort_on_dependent: true, user_install: true)
          ui.action("Uninstalling the #{name} gem") { Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) { uninstaller.uninstall } }
          0
        rescue Gem::DependencyRemovalException
          ui.warning("Left the #{name} gem installed, since other gems depend on it.")
          0
        rescue Gem::Exception => e
          raise Hatchbox::Error, "hatchbox won't load #{name} anymore, but its gem is still installed: #{e.message}\ngem uninstall #{name} removes it."
        end

        def removable?(name)
          return false if name == "hatchbox"

          Gem::Specification.find_all_by_name(name).any? { |spec| !spec.default_gem? }
        end
      end
    end
  end
end
