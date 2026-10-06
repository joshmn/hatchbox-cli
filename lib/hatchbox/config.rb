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
      "#{Hatchbox.tilde(root)} in #{store.display_path}"
    end

    def exists?
      apps.any?
    end

    def apps
      remote_map.to_a
    end

    def remotes
      remote_map.keys
    end

    def app_for(remote)
      remote_map[remote]
    end

    def default
      value = project["default"]
      Hatchbox.blank?(value) ? nil : value
    end

    def ssh(remote:, key:)
      return nil if remote.nil?

      value = (project.fetch("ssh", {})[remote] || {})[key]
      Hatchbox.blank?(value) ? nil : value.to_s
    end

    def ssh_hint(remote:, key:)
      "Set \"#{key}\" under ssh.#{remote || "REMOTE"} for #{location}."
    end

    def set_app(remote:, app:)
      change { |entry| (entry["remotes"] ||= {})[remote] = app }
    end

    def set_default(remote)
      change { |entry| entry["default"] = remote }
    end

    def remove_app_id(app_id)
      gone = apps.select { |_remote, slug| Hatchbox.slug_id(slug) == app_id.to_s }.map { |remote, _slug| remote }
      change { |entry| forget(entry: entry, remotes: gone) } if gone.any?
      gone
    end

    def rename_app_id(app_id:, slug:)
      moved = apps.select { |_remote, existing| Hatchbox.slug_id(existing) == app_id.to_s }.map { |remote, _slug| remote }
      change { |entry| moved.each { |remote| entry["remotes"][remote] = slug } } if moved.any?
      moved
    end

    private

    attr_reader :store

    def project
      store.data.fetch("projects", {})[root] || {}
    end

    def remote_map
      project.fetch("remotes", {})
    end

    def forget(entry:, remotes:)
      remotes.each { |remote| entry["remotes"].delete(remote) }
      entry.delete("default") if remotes.include?(entry["default"])
    end

    def change
      store.update do |data|
        entry = (data["projects"] ||= {})[root] ||= {}
        yield(entry)
      end
    end
  end
end
