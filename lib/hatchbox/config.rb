# frozen_string_literal: true

module Hatchbox
  class Config
    HEADER = [
      "# the apps this repo deploys to, written the way the dashboard url spells them,",
      "# then the environment each one is. pick one with -r, or run hatchbox git:remote to add another."
    ].freeze

    def initialize(path)
      @file = Hatchbox::ConfigFile.new(path)
    end

    def path
      file.path
    end

    def exists?
      file.exists?
    end

    def get(key)
      value = file.settings[key]
      Hatchbox.blank?(value) ? nil : value
    end

    def set(key:, value:)
      raise Hatchbox::Error, "#{path} is not writable." unless file.writable?

      file.rewrite("#{key} = #{value}") { |line| Hatchbox::ConfigLine.key(line) == key }
    end

    def unset(key)
      return unless exists? && file.writable?

      file.rewrite(nil) { |line| Hatchbox::ConfigLine.key(line) == key }
    end

    def apps
      file.lines.map { |line| Hatchbox::ConfigLine.remote(line) }.compact
    end

    def envs
      apps.map { |env, _app| env }
    end

    def app_for(env)
      found = apps.select { |name, _app| name == env }.last
      found ? found.last : nil
    end

    def set_app(env:, app:)
      file.write(HEADER.dup) unless exists?
      raise Hatchbox::Error, "#{path} is not writable." unless file.writable?

      file.rewrite("#{app}:#{env}") { |line| line_env(line) == env }
    end

    def remove_app_id(app_id)
      return [] unless exists? && file.writable?

      gone = apps.select { |_env, slug| Hatchbox.slug_id(slug) == app_id.to_s }.map { |env, _slug| env }
      file.write(file.lines.reject { |line| points_at?(line: line, app_id: app_id) })
      gone
    end

    def rename_app_id(app_id:, slug:)
      return [] unless exists? && file.writable?

      moved = []
      rows = file.lines.map do |line|
        next line unless points_at?(line: line, app_id: app_id)

        env = line_env(line)
        moved << env
        "#{slug}:#{env}"
      end
      file.write(rows)
      moved
    end

    private

    attr_reader :file

    def line_env(line)
      pair = Hatchbox::ConfigLine.remote(line)
      pair ? pair.first : nil
    end

    def points_at?(line:, app_id:)
      pair = Hatchbox::ConfigLine.remote(line)
      return false unless pair

      Hatchbox.slug_id(pair.last) == app_id.to_s
    end
  end
end
