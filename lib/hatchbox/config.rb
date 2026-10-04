# frozen_string_literal: true

module Hatchbox
  class Config
    SSH_KEYS = ["host", "port", "user", "app_dir"].freeze

    attr_reader :root

    def initialize(store:, root:)
      @store = store
      @root = root
    end

    def location
      "#{root.sub(/\A#{Regexp.escape(Dir.home)}/, "~")} in #{store.display_path}"
    end

    def exists?
      apps.any?
    end

    def apps
      remotes.to_a
    end

    def envs
      remotes.keys
    end

    def app_for(env)
      remotes[env]
    end

    def default
      value = project["default"]
      Hatchbox.blank?(value) ? nil : value
    end

    def ssh(env:, key:)
      return nil if env.nil?

      value = (project.fetch("ssh", {})[env] || {})[key]
      Hatchbox.blank?(value) ? nil : value.to_s
    end

    def ssh_hint(env:, key:)
      "Set \"#{key}\" under ssh.#{env || "REMOTE"} for #{location}."
    end

    def set_app(env:, app:)
      change { |entry| (entry["remotes"] ||= {})[env] = app }
    end

    def set_default(env)
      change { |entry| entry["default"] = env }
    end

    def remove_app_id(app_id)
      gone = apps.select { |_env, slug| Hatchbox.slug_id(slug) == app_id.to_s }.map { |env, _slug| env }
      change { |entry| forget(entry: entry, envs: gone) } if gone.any?
      gone
    end

    def rename_app_id(app_id:, slug:)
      moved = apps.select { |_env, existing| Hatchbox.slug_id(existing) == app_id.to_s }.map { |env, _slug| env }
      change { |entry| moved.each { |env| entry["remotes"][env] = slug } } if moved.any?
      moved
    end

    private

    attr_reader :store

    def project
      store.data.fetch("projects", {})[root] || {}
    end

    def remotes
      project.fetch("remotes", {})
    end

    def forget(entry:, envs:)
      envs.each { |env| entry["remotes"].delete(env) }
      entry.delete("default") if envs.include?(entry["default"])
    end

    def change
      store.update do |data|
        entry = (data["projects"] ||= {})[root] ||= {}
        yield(entry)
      end
    end
  end
end
