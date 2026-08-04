#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "optparse"
require "pathname"
require "socket"
require "shellwords"
require "tmpdir"
require "fileutils"
require "io/console"
require "open3"
require "rbconfig"

class String
  def red
    ansi(31)
  end

  def green
    ansi(32)
  end

  def yellow
    ansi(33)
  end

  def cyan
    ansi(36)
  end

  def dim
    ansi(90)
  end

  private

  def ansi(code)
    return self unless Hatchbox.color?

    "\e[#{code}m#{self}\e[0m"
  end
end

module Hatchbox
  API_BASE = ENV["HATCHBOX_API_BASE"] || "https://hatchbox.io/api/v1"
  GLOBAL_CONFIG = File.join(Dir.home, ".hatchbox")
  POLL_SECONDS = 3
  MAX_WAIT_SECONDS = 3600
  DEFAULT_SSH_USER = "deploy"
  DEFAULT_SSH_PORT = "22"

  class Error < StandardError; end

  class << self
    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def color?
      return false if ENV["NO_COLOR"]

      $stdout.tty?
    end

    def run(argv, env: {})
      started = system(env, *argv)
      raise Error, "#{argv.first} is required and is not installed" if started.nil?

      $?.exitstatus.to_i
    end

    def parallel(jobs)
      threads = jobs.map do |key, job|
        thread = Thread.new do
          Thread.current.report_on_exception = false
          job.call
        end
        [key, thread]
      end
      threads.to_h { |key, thread| [key, thread.value] }
    end

    def slug_id(slug)
      slug.to_s[/\A[0-9]+/]
    end

    def slug_name(slug)
      slug.to_s.sub(/\A[0-9]+-?/, "")
    end
  end
end

module Hatchbox::Ui
  class << self
    def header(text)
      puts(text.cyan)
    end

    def list(words)
      items = words.map { |word| word.to_s }
      return items.first.to_s if items.length < 2

      "#{items[0..-2].join(", ")} and #{items.last}"
    end

    def confirm(expected:, supplied:, action:)
      return if supplied == expected

      prompt = Hatchbox::Prompt.new
      raise Hatchbox::Error, "#{action}. run it again with --confirm #{expected}" unless prompt.available?

      answer = prompt.ask(question: "#{action}. type #{expected} to confirm: ", io: $stderr)
      raise Hatchbox::Error, "left #{expected} alone" unless answer == expected
    end
  end
end

class Hatchbox::Http
  METHODS = {
    "GET" => Net::HTTP::Get,
    "POST" => Net::HTTP::Post,
    "PUT" => Net::HTTP::Put,
    "PATCH" => Net::HTTP::Patch,
    "DELETE" => Net::HTTP::Delete
  }.freeze

  class Response
    attr_reader :code, :body, :json

    def initialize(code:, body:)
      @code = code
      @body = body
      @json = parse(body)
    end

    def ok?
      code >= 200 && code < 300
    end

    private

    def parse(text)
      return nil if text.to_s.strip.empty?

      JSON.parse(text)
    rescue JSON::ParserError
      nil
    end
  end

  def initialize(base:, token:)
    @base = base
    @token = token
  end

  def request(method:, path:, body: nil)
    uri = URI.parse("#{base}#{path}")
    response = perform(uri: uri, message: build(method: method, uri: uri, body: body))
    Response.new(code: response.code.to_i, body: response.body.to_s)
  end

  private

  attr_reader :base, :token

  def build(method:, uri:, body:)
    message = METHODS.fetch(method).new(uri.request_uri)
    message["Authorization"] = "Bearer #{token}"
    message["Accept"] = "application/json"
    if body
      message["Content-Type"] = "application/json"
      message.body = JSON.dump(body)
    end
    message
  end

  def perform(uri:, message:)
    session(uri).request(message)
  rescue StandardError => e
    drop(uri)
    raise Hatchbox::Error, "request to #{uri} failed, #{e.message}"
  end

  def session(uri)
    pool = (Thread.current[:hatchbox_sessions] ||= {})
    key = "#{uri.scheme}://#{uri.host}:#{uri.port}"
    open = pool[key]
    return open if open && open.started?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 15
    http.read_timeout = 60
    http.start
    pool[key] = http
  end

  def drop(uri)
    pool = Thread.current[:hatchbox_sessions] || {}
    open = pool.delete("#{uri.scheme}://#{uri.host}:#{uri.port}")
    open.finish if open && open.started?
  rescue StandardError
    nil
  end
end

class Hatchbox::Client
  def initialize(token:)
    @http = Hatchbox::Http.new(base: Hatchbox::API_BASE, token: token)
  end

  def get(path)
    ensure_ok(raw("GET", path))
  end

  def post(path, body: nil)
    ensure_ok(raw("POST", path, body: body))
  end

  def put(path, body: nil)
    ensure_ok(raw("PUT", path, body: body))
  end

  def patch(path, body: nil)
    ensure_ok(raw("PATCH", path, body: body))
  end

  def delete(path, body: nil)
    ensure_ok(raw("DELETE", path, body: body))
  end

  def raw(method, path, body: nil)
    http.request(method: method, path: path, body: body)
  end

  def error_message(response)
    return "hatchbox turned the token down. run hatchbox auth:login, or check HATCHBOX_API_TOKEN" if response.code == 401

    data = response.json
    return "http #{response.code}" unless data.is_a?(Hash)

    detail = data["error"].to_s
    detail = Array(data["errors"]).join(", ") if detail.empty?
    detail.empty? ? "http #{response.code}" : detail
  end

  private

  attr_reader :http

  def ensure_ok(response)
    return response if response.ok?

    raise Hatchbox::Error, response.code == 401 ? error_message(response) : "hatchbox said: #{error_message(response)}"
  end
end

class Hatchbox::Config
  HEADER = [
    "# the apps this repo deploys to, written the way the dashboard url spells them,",
    "# then the environment each one is. run hatchbox git:remote to add another."
  ].freeze

  class << self
    def find
      Pathname.new(Dir.pwd).ascend do |dir|
        candidate = dir.join(".hatchbox")
        return candidate.to_s if candidate.file? && candidate.to_s != Hatchbox::GLOBAL_CONFIG
      end
      nil
    end

    def target
      found = find
      return found if found

      repo = Pathname.new(Dir.pwd).ascend { |dir| break dir if dir.join(".git").exist? }
      File.join((repo || Dir.pwd).to_s, ".hatchbox")
    end
  end

  attr_reader :path

  def initialize(path)
    @path = path.to_s
  end

  def exists?
    File.file?(path)
  end

  def get(key)
    value = settings[key]
    Hatchbox.blank?(value) ? nil : value
  end

  def set(key:, value:)
    unless writable?
      warn("could not write #{key} to #{path}, it is not writable".yellow)
      return
    end

    rewrite("#{key} = #{value}") { |line| setting_key(line) == key }
  end

  def unset(key)
    return unless exists? && writable?

    rewrite(nil) { |line| setting_key(line) == key }
  end

  def apps
    lines.map { |line| split_app(line) }.compact
  end

  def envs
    apps.map { |env, _app| env }
  end

  def app_for(env)
    found = apps.select { |name, _app| name == env }.last
    found ? found.last : nil
  end

  def set_app(env:, app:)
    write(HEADER.dup) unless exists?
    raise Hatchbox::Error, "#{path} is not writable" unless writable?

    rewrite("#{app}:#{env}") { |line| line_env(line) == env }
  end

  def remove_app_id(app_id)
    return [] unless exists? && writable?

    gone = apps.select { |_env, slug| Hatchbox.slug_id(slug) == app_id.to_s }.map { |env, _slug| env }
    write(lines.reject { |line| (pair = split_app(line)) && Hatchbox.slug_id(pair.last) == app_id.to_s })
    gone
  end

  def rename_app_id(app_id:, slug:)
    return [] unless exists? && writable?

    moved = []
    rows = lines.map do |line|
      pair = split_app(line)
      next line unless pair && Hatchbox.slug_id(pair.last) == app_id.to_s

      moved << pair.first
      "#{slug}:#{pair.first}"
    end
    write(rows)
    moved
  end

  private

  def rewrite(replacement)
    written = false
    kept = lines.map do |line|
      next line unless yield(line)
      next nil if written || replacement.nil?

      written = true
      replacement
    end
    kept = kept.compact
    kept << replacement unless written || replacement.nil?
    write(kept)
  end

  def lines
    return [] unless exists?

    File.readlines(path).map { |line| line.chomp }
  end

  def settings
    found = {}
    lines.each do |line|
      key = setting_key(line)
      found[key] = line.split("=", 2).last.strip if key
    end
    found
  end

  def write(rows)
    File.write(path, rows.map { |row| "#{row}\n" }.join)
  end

  def writable?
    return File.writable?(path) if exists?

    File.writable?(File.dirname(path))
  end

  def setting_key(line)
    text = line.strip
    return nil if text.start_with?("#") || !text.include?("=")

    text.split("=", 2).first.strip
  end

  def line_env(line)
    pair = split_app(line)
    pair ? pair.first : nil
  end

  def split_app(line)
    text = line.strip
    return nil if text.empty? || text.start_with?("#") || text.include?("=")

    app, _colon, env = text.rpartition(":")
    return nil if app.strip.empty? || env.strip.empty?

    [env.strip, app.strip]
  end
end

class Hatchbox::Prompt
  def available?
    !tty.nil?
  end

  def ask(question:, io: $stdout)
    return nil unless available?

    io.print(question)
    io.flush
    answer = tty.gets
    answer.nil? ? nil : answer.strip
  end

  def secret(question:, io: $stdout)
    return nil unless available?

    io.print(question)
    io.flush
    answer = tty.noecho { |input| input.gets }
    io.puts
    answer.nil? ? nil : answer.strip
  end

  def ask_number(question:, count:, io: $stdout)
    answer = ask(question: question, io: io).to_s
    raise Hatchbox::Error, "that is not a number" unless answer =~ /\A[0-9]+\z/
    raise Hatchbox::Error, "there is no #{answer} on that list" if answer.to_i < 1 || answer.to_i > count

    answer.to_i
  end

  private

  def tty
    return @tty if @opened

    @opened = true
    @tty = begin
      File.open("/dev/tty", "r")
    rescue SystemCallError
      nil
    end
  end
end

class Hatchbox::TokenStore
  def initialize(prompt: Hatchbox::Prompt.new)
    @prompt = prompt
    @global = Hatchbox::Config.new(Hatchbox::GLOBAL_CONFIG)
  end

  def path
    global.path
  end

  def read(env: nil)
    from_env = ENV["HATCHBOX_API_TOKEN"]
    return from_env unless Hatchbox.blank?(from_env)

    scoped = env ? global.get("token:#{env}") : nil
    return scoped unless Hatchbox.blank?(scoped)

    global.get("token")
  end

  def source(env: nil)
    return "HATCHBOX_API_TOKEN" unless Hatchbox.blank?(ENV["HATCHBOX_API_TOKEN"])
    return "token:#{env} in #{path}" if env && !Hatchbox.blank?(global.get("token:#{env}"))
    return path unless Hatchbox.blank?(global.get("token"))

    nil
  end

  def ask
    raise Hatchbox::Error, "no terminal to ask for a token on. set HATCHBOX_API_TOKEN" unless prompt.available?

    puts("paste an api token, hatchbox has them under api tokens in your account settings.")
    token = prompt.secret(question: "token: ")
    raise Hatchbox::Error, "nothing entered" if Hatchbox.blank?(token)

    token
  end

  def ensure_token
    token = read
    return token unless Hatchbox.blank?(token)

    token = ask
    save(token)
    puts("saved it to #{path}".green)
    puts
    token
  end

  def save(token)
    kept = lines.reject { |line| key_of(line) == "token" }
    File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
      (kept + ["token = #{token}"]).each { |line| file.puts(line) }
    end
    File.chmod(0o600, path)
  end

  def forget
    found = lines.select { |line| token_key?(key_of(line)) }
    return 0 if found.empty?

    kept = lines.reject { |line| token_key?(key_of(line)) }
    File.open(path, File::WRONLY | File::TRUNC, 0o600) { |file| kept.each { |line| file.puts(line) } }
    found.length
  end

  private

  attr_reader :prompt, :global

  def lines
    return [] unless File.file?(path)

    File.readlines(path).map { |line| line.chomp }
  end

  def key_of(line)
    text = line.strip
    return nil if text.start_with?("#") || !text.include?("=")

    text.split("=", 2).first.strip
  end

  def token_key?(key)
    key == "token" || key.to_s.start_with?("token:")
  end
end

class Hatchbox::AppCatalog
  def initialize(client:)
    @client = client
    @apps = {}
    @skipped = {}
    @clusters = {}
    @database_clusters = {}
  end

  def accounts
    @accounts ||= client.get("/accounts").json || []
  end

  def entries(filter: nil)
    load_apps
    rows = accounts.flat_map do |account|
      (@apps[account["id"].to_s] || []).map { |app| entry(account: account, app: app) }
    end
    return rows if Hatchbox.blank?(filter)

    wanted = filter.downcase
    rows.select { |row| row[:slug].downcase.include?(wanted) || row[:name].downcase.include?(wanted) }
  end

  def named(name)
    entries.select { |row| row[:name].casecmp?(name.to_s) }
  end

  def account_for(app_id)
    found = entries.find { |row| row[:id] == app_id.to_s }
    found ? found[:account_record] : nil
  end

  def skipped
    load_apps
    @skipped
  end

  def usable_accounts
    load_apps
    accounts.reject { |account| @skipped.key?(account["name"].to_s) }
  end

  def find_account(wanted)
    pool = usable_accounts
    if Hatchbox.blank?(wanted)
      return pool.first if pool.length == 1
      raise Hatchbox::Error, "the token reaches no account with an active subscription" if pool.empty?

      raise Hatchbox::Error, "more than one account, so pick one with --account\n\n#{pool.map { |account| "  #{account["name"]}, account #{account["id"]}" }.join("\n")}"
    end

    found = accounts.find do |account|
      [account["id"].to_s, "acct_#{account["id"]}"].include?(wanted.to_s) || account["name"].to_s.casecmp?(wanted.to_s)
    end
    raise Hatchbox::Error, "no account called #{wanted}" unless found

    found
  end

  def clusters_for(account)
    key = account["id"].to_s
    @clusters[key] ||= client.get("/accounts/#{key}/clusters").json || []
  end

  def database_clusters_for(account)
    key = account["id"].to_s
    @database_clusters[key] ||= client.get("/accounts/#{key}/database_clusters").json || []
  end

  def git_providers_for(account)
    client.get("/accounts/#{account["id"]}/git_providers").json || []
  end

  private

  attr_reader :client

  def load_apps
    return if @loaded

    @loaded = true
    jobs = accounts.to_h { |account| [account["id"].to_s, -> { client.raw("GET", "/accounts/#{account["id"]}/apps") }] }
    Hatchbox.parallel(jobs).each do |key, response|
      account = accounts.find { |row| row["id"].to_s == key }
      if response.ok?
        @apps[key] = response.json || []
      else
        @skipped[account["name"].to_s] = client.error_message(response)
      end
    end
  end

  def entry(account:, app:)
    {
      id: app["id"].to_s,
      name: app["name"].to_s,
      slug: "#{app["id"]}-#{app["name"]}",
      cluster_id: app["cluster_id"].to_s,
      account: account["name"].to_s,
      account_record: account,
      record: app
    }
  end
end

class Hatchbox::Target
  attr_reader :env, :slug

  def initialize(session:)
    @session = session
  end

  def resolve
    return self if @resolved

    @resolved = true
    return by_app(session.app_flag) unless Hatchbox.blank?(session.app_flag)
    return by_remote(session.remote_flag) unless Hatchbox.blank?(session.remote_flag)
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

  def by_app(value)
    text = value.to_s.strip
    match = text.match(/\A([0-9]+)(?:-(.+))?\z/)
    if match
      @app_id = match[1]
      entry = config.apps.find { |_env, slug| Hatchbox.slug_id(slug) == @app_id }
      @env = entry ? entry.first : nil
      @slug = match[2] ? text : (entry ? entry.last : text)
      return self
    end

    known = config.apps.select { |_env, slug| Hatchbox.slug_name(slug).casecmp?(text) }
    if known.map { |_env, slug| slug }.uniq.length == 1
      @env, @slug = known.first
      @app_id = Hatchbox.slug_id(@slug)
      return self
    end

    @wanted = text
    self
  end

  def by_remote(name)
    raise Hatchbox::Error, no_app_message unless config.exists?

    found = config.app_for(name)
    raise Hatchbox::Error, "no remote called #{name} in #{config.path}\n\n#{remotes_line}" if Hatchbox.blank?(found)

    @env = name
    @slug = found
    @app_id = Hatchbox.slug_id(found)
    raise Hatchbox::Error, "#{found} in #{config.path} does not start with the app's id, the way the dashboard url spells it" if Hatchbox.blank?(@app_id)

    self
  end

  def by_default
    raise Hatchbox::Error, no_app_message if !config.exists? || config.envs.empty?

    name = config.get("default")
    name = config.envs.first if Hatchbox.blank?(name) && config.envs.uniq.length == 1
    raise Hatchbox::Error, multiple_message if Hatchbox.blank?(name)

    by_remote(name)
  end

  def lookup
    found = Hatchbox::AppCatalog.new(client: session.client).named(@wanted)
    raise Hatchbox::Error, "no app called #{@wanted} on any account the token reaches" if found.empty?
    if found.length > 1
      rows = found.map { |row| "  #{row[:slug]}, #{row[:account]}" }.join("\n")
      raise Hatchbox::Error, "more than one app is called #{@wanted}, so use its id with -a\n\n#{rows}"
    end

    @slug = found.first[:slug]
    found.first[:id]
  end

  def no_app_message
    "no .hatchbox here or above #{Dir.pwd} names an app. pass -a APP, or add one with hatchbox git:remote"
  end

  def multiple_message
    "#{config.path} has more than one remote and no default line, so pick one with -a or -r\n\n#{remotes_line}"
  end

  def remotes_line
    return "it names no apps, add one with hatchbox git:remote" if config.envs.empty?

    "remotes it does know about:\n#{config.envs.uniq.map { |name| "  #{name}" }.join("\n")}"
  end
end

class Hatchbox::Session
  attr_reader :app_flag, :remote_flag

  def initialize(app_flag: nil, remote_flag: nil)
    @app_flag = app_flag
    @remote_flag = remote_flag
  end

  def config
    @config ||= Hatchbox::Config.new(Hatchbox::Config.find || File.join(Dir.pwd, ".hatchbox"))
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
    @token ||= begin
      scope = @target ? @target.env : remote_flag
      found = Hatchbox::TokenStore.new.read(env: scope)
      raise Hatchbox::Error, "no api token. run hatchbox auth:login or set HATCHBOX_API_TOKEN" if Hatchbox.blank?(found)

      found
    end
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
end

class Hatchbox::App
  attr_reader :id, :slug

  def initialize(client:, app_id:, slug: nil)
    @client = client
    @id = app_id.to_s
    @slug = slug
  end

  def details
    @details ||= client.get("/apps/#{id}").json || {}
  end

  def name
    details["name"].to_s
  end

  def label
    from_slug = Hatchbox.slug_name(slug)
    return from_slug unless from_slug.empty?

    name.empty? ? id : name
  end

  def cluster
    @cluster ||= begin
      cluster_id = details["cluster_id"]
      raise Hatchbox::Error, "#{label} is on no cluster, so there is no server to reach" if Hatchbox.blank?(cluster_id)

      client.get("/clusters/#{cluster_id}").json || {}
    end
  end

  def servers
    cluster["servers"] || []
  end

  def processes
    @processes ||= client.get("/apps/#{id}/processes").json || []
  end

  def domains
    @domains ||= client.get("/apps/#{id}/domains").json || []
  end

  def env_var_names
    @env_var_names ||= (client.get("/apps/#{id}/env_vars").json || []).map { |row| row["name"].to_s }
  end

  def databases
    @databases ||= client.get("/apps/#{id}/databases").json || []
  end

  def server_name(server_id)
    match = servers.find { |server| server["id"].to_s == server_id.to_s }
    return "server #{server_id}" if match.nil? || Hatchbox.blank?(match["name"])

    match["name"]
  rescue Hatchbox::Error
    "server #{server_id}"
  end

  def web_url
    found = domains.map { |row| row["name"].to_s }.reject { |host| host.start_with?("*") }.first
    found ? "https://#{found}/" : nil
  end

  private

  attr_reader :client
end

class Hatchbox::ProcessCatalog
  NAME = /\A[A-Za-z0-9_-]+\z/.freeze

  class << self
    def label(row)
      row["name"].to_s
    end

    def state(row)
      row["active"] ? "on" : "off"
    end

    def where(row)
      return "server #{row["server_id"]}" unless Hatchbox.blank?(row["server_id"])

      roles = (row["roles"] || []).map { |role| role.to_s }
      roles.empty? ? "nowhere" : roles.join(", ")
    end

    def detail(row)
      [
        ["state", row["active"] ? "on" : "off"],
        ["runs on", where(row)],
        ["start", row["start_command"]],
        ["stop", row["stop_command"]],
        ["reload", row["reload_command"]],
        ["socket", row["socket"] ? "yes" : "no"],
        ["systemd type", row["systemd_type"]],
        ["on deploy", row["restart_on_deploy"] ? "restarts" : "left alone"],
        ["appsignal", row["appsignal"]],
        ["created", row["created_at"]],
        ["updated", row["updated_at"]]
      ].map { |key, value| "  #{key.ljust(14)}#{Hatchbox.blank?(value) ? "-" : value}" }.join("\n")
    end
  end

  def initialize(client:, app_id:)
    @client = client
    @app_id = app_id
  end

  def all
    @all ||= client.get("/apps/#{app_id}/processes").json || []
  end

  def find(wanted)
    raise Hatchbox::Error, "which process?\n\n#{listing}" if Hatchbox.blank?(wanted)
    raise Hatchbox::Error, "this app has no processes yet" if all.empty?

    exact = all.find { |row| self.class.label(row).downcase == wanted.to_s.downcase || row["id"].to_s == wanted.to_s }
    return exact if exact

    near = all.select { |row| self.class.label(row).downcase.include?(wanted.to_s.downcase) }
    return near.first if near.length == 1
    raise Hatchbox::Error, "#{wanted} matches more than one process, #{near.map { |row| self.class.label(row) }.join(" and ")}" if near.length > 1

    raise Hatchbox::Error, "no process called #{wanted}\n\n#{listing}"
  end

  def table(rows = all)
    return "  none" if rows.empty?

    width = rows.map { |row| self.class.label(row).length }.max
    place = rows.map { |row| self.class.where(row).length }.max
    rows.map { |row| line(row: row, width: width, place: place) }.join("\n")
  end

  def listing
    return "this app has no processes yet" if all.empty?

    "processes on this app\n#{table}"
  end

  private

  attr_reader :client, :app_id

  def line(row:, width:, place:)
    state = row["active"] ? "on ".green : "off".yellow
    id = row["id"].to_s.rjust(6)
    "  #{self.class.label(row).ljust(width)}  #{id}  #{state}  #{self.class.where(row).ljust(place)}  #{row["start_command"]}"
  end
end

class Hatchbox::ServerPicker
  def initialize(app:, prompt:)
    @app = app
    @prompt = prompt
  end

  def pick(filter)
    pool = Hatchbox.blank?(filter) ? app.servers : matching(filter)
    raise Hatchbox::Error, "#{nothing_message(filter)}\n\n#{listing(app.servers)}" if pool.empty?
    return pool.first if pool.length == 1
    raise Hatchbox::Error, "that cluster has more than one server, so name one with --server\n\n#{listing(pool)}" unless prompt.available?

    choose(pool)
  end

  private

  attr_reader :app, :prompt

  def matching(filter)
    wanted = filter.downcase
    app.servers.select do |server|
      roles(server).map { |role| role.downcase }.include?(wanted) || label(server).downcase.include?(wanted)
    end
  end

  def nothing_message(filter)
    return "that cluster has no servers" if Hatchbox.blank?(filter)

    "no server called #{filter}, and none with that role"
  end

  def listing(pool)
    pool.map { |server| "  #{label(server)}  #{roles(server).join(", ")}" }.join("\n")
  end

  def label(server)
    Hatchbox.blank?(server["name"]) ? "unnamed" : server["name"]
  end

  def roles(server)
    (server["roles"] || []).map { |role| role.to_s }
  end

  def choose(pool)
    warn("servers on this cluster")
    pool.each_with_index { |server, index| warn("  #{index + 1}  #{label(server)}  #{roles(server).join(", ")}") }
    warn("")
    pool[prompt.ask_number(question: "which one? ", count: pool.length, io: $stderr) - 1]
  end
end

class Hatchbox::SshTarget
  class << self
    def resolve(session:, filter: nil, picker: nil)
      new(session: session, filter: filter, picker: picker).resolve
    end
  end

  attr_reader :host, :user, :port, :server

  def initialize(session:, filter: nil, picker: nil)
    @session = session
    @filter = filter
    @picker = picker
  end

  def resolve
    @host = setting("ssh_host")
    @user = setting("ssh_user") || Hatchbox::DEFAULT_SSH_USER
    @port = setting("ssh_port")
    from_cluster if Hatchbox.blank?(host)
    @port ||= Hatchbox::DEFAULT_SSH_PORT
    self
  end

  def address
    "#{user}@#{host}"
  end

  def server_label
    return nil unless server

    Hatchbox.blank?(server["name"]) ? "server" : server["name"]
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
    raise Hatchbox::Error, "no release directory to run rails in. set app_dir:#{session.env || "ENV"} in #{session.config.path}" if Hatchbox.blank?(dir)

    complaint = "#{dir} is not there, so nothing is deployed yet. set app_dir:#{session.env || "ENV"} in .hatchbox if the app lives somewhere else"
    "cd #{Shellwords.escape(dir)} 2>/dev/null || { echo #{Shellwords.escape(complaint)} >&2; exit 1; }"
  end

  def ssh(command: nil, tty: false, extra: [])
    argv = ["ssh", "-p", port.to_s]
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

  attr_reader :session, :filter

  def picker
    @picker ||= Hatchbox::ServerPicker.new(app: session.app, prompt: session.prompt)
  end

  def from_cluster
    @server = picker.pick(filter)
    @host = server["public_ip"].to_s
    @port ||= server["ssh_port"].to_s unless Hatchbox.blank?(server["ssh_port"])
    return unless Hatchbox.blank?(host)

    raise Hatchbox::Error, "#{server_label} has no public ip. set ssh_host:#{session.env || "ENV"} in #{session.config.path}"
  end

  def setting(key)
    return nil if session.env.nil?

    session.config.get("#{key}:#{session.env}")
  end
end

class Hatchbox::DatabasePicker
  def initialize(session:)
    @session = session
  end

  def pick(_filter)
    servers = session.app.servers
    found = servers.find { |server| (server["roles"] || []).include?("postgresql") }
    found = servers.first if found.nil? && servers.length == 1
    raise Hatchbox::Error, "could not tell which server holds the database. set ssh_host:#{session.env || "ENV"} in #{session.config.path}" unless found

    found
  end

  private

  attr_reader :session
end

class Hatchbox::Database
  def initialize(text)
    @uri = URI.parse(text)
  rescue URI::InvalidURIError
    raise Hatchbox::Error, "could not read the connection uri hatchbox returned"
  end

  def user
    decode(uri.user)
  end

  def password
    decode(uri.password)
  end

  def host
    uri.host.to_s
  end

  def port
    (uri.port || 5432).to_s
  end

  def name
    decode(uri.path.to_s.sub(%r{\A/}, ""))
  end

  def sslmode
    found = URI.decode_www_form(uri.query.to_s).to_h["sslmode"]
    Hatchbox.blank?(found) ? "prefer" : found
  end

  private

  attr_reader :uri

  def decode(value)
    value.nil? ? "" : URI.decode_www_form_component(value)
  end
end

class Hatchbox::Tunnel
  class << self
    def open(session:, host:, port:)
      new(session: session, host: host, port: port).open
    end
  end

  attr_reader :local_port

  def initialize(session:, host:, port:)
    @session = session
    @host = host
    @port = port
  end

  def open
    @target = Hatchbox::SshTarget.resolve(session: session, picker: Hatchbox::DatabasePicker.new(session: session))
    @local_port = free_port
    @dir = Dir.mktmpdir("hbx", "/tmp")
    warn("tunnelling to #{host}:#{port} through #{target.address}".dim)
    raise Hatchbox::Error, failure_message unless Hatchbox.run(ssh_command).zero?

    self
  end

  def close
    Hatchbox.run(["ssh", "-S", control, "-O", "exit", "-o", "LogLevel=QUIET", target.address])
    FileUtils.remove_entry(dir)
  end

  private

  attr_reader :session, :host, :port, :dir, :target

  def control
    File.join(dir, "control")
  end

  def ssh_command
    [
      "ssh", "-f", "-N", "-M", "-S", control,
      "-o", "ExitOnForwardFailure=yes", "-o", "ConnectTimeout=10",
      "-p", target.port.to_s, "-L", "127.0.0.1:#{local_port}:#{host}:#{port}", target.address
    ]
  end

  def failure_message
    "could not open an ssh tunnel. hatchbox puts your key on the deploy user, so\n" \
      "check that ssh #{target.address} works, or set ssh_user:#{session.env || "ENV"} in #{session.config.path}"
  end

  def free_port
    socket = TCPServer.new("127.0.0.1", 0)
    picked = socket.addr[1]
    socket.close
    picked
  end
end

class Hatchbox::LogStream
  ENDED = ["completed", "failed", "aborted"].freeze

  def initialize(client:, app:, log_id:)
    @client = client
    @app = app
    @log_id = log_id
    @seen = {}
    @headers = {}
  end

  def show
    data = fetch
    puts("log #{log_id.to_s.cyan}, #{data["name"] || "unknown"}, #{data["state"] || "unknown"}")
    puts(commit_line(data)) if commit_line(data)
    puts("started by #{data["username"]}".dim) unless Hatchbox.blank?(data["username"])
    puts

    follow
  end

  def follow
    waited = 0
    loop do
      data = fetch
      emit(key: "parent", text: data["body"].to_s)
      emit_children(data)
      state = data["state"].to_s
      return finish(state) if ENDED.include?(state)
      return give_up(state) if waited >= Hatchbox::MAX_WAIT_SECONDS

      sleep(Hatchbox::POLL_SECONDS)
      waited += Hatchbox::POLL_SECONDS
    end
  end

  private

  attr_reader :client, :app, :log_id, :seen, :headers

  def fetch
    client.get("/logs/#{log_id}").json || {}
  end

  def commit_line(data)
    sha = data["commit_sha"].to_s
    return nil if sha.empty?

    description = data["description"].to_s
    line = "commit #{sha[0, 7].cyan}"
    description.empty? ? line : "#{line} #{description}"
  end

  def emit(key:, text:)
    old = seen[key].to_s
    if old.empty?
      print(text) unless text.empty?
    elsif text.length > old.length && text.start_with?(old)
      print(text[old.length..-1])
    elsif text != old
      print(text)
    end
    $stdout.flush
    seen[key] = text
  end

  def emit_children(data)
    (data["child_logs"] || []).each do |child|
      text = child["body"].to_s
      id = child["id"]
      if !text.empty? && !headers[id]
        puts
        puts("output from #{app.server_name(child["loggable_id"])}".cyan)
        headers[id] = true
      end
      emit(key: "child-#{id}", text: text)
    end
  end

  def finish(state)
    puts
    puts(state == "completed" ? state.green : state.red)
    state == "completed"
  end

  def give_up(state)
    puts
    puts("gave up watching after #{Hatchbox::MAX_WAIT_SECONDS / 60} minutes, still #{state}".yellow)
    puts("pick it back up with hatchbox releases:output #{log_id}".dim)
    false
  end
end

class Hatchbox::FixedPicker
  def initialize(server)
    @server = server
  end

  def pick(_filter)
    @server
  end
end

class Hatchbox::ProcessTarget
  class << self
    def resolve(session:, process:, filter: nil)
      new(session: session, process: process, filter: filter).resolve
    end
  end

  def initialize(session:, process:, filter: nil)
    @session = session
    @process = process
    @filter = filter
  end

  def resolve
    Hatchbox::SshTarget.resolve(session: session, filter: role_filter, picker: pinned)
  end

  private

  attr_reader :session, :process, :filter

  def role_filter
    return filter unless Hatchbox.blank?(filter)
    return nil if process.nil?

    (process["roles"] || []).map { |role| role.to_s }.first
  end

  def pinned
    return nil if process.nil? || !Hatchbox.blank?(filter)

    id = process["server_id"]
    return nil if Hatchbox.blank?(id)

    found = session.app.servers.find { |server| server["id"].to_s == id.to_s }
    raise Hatchbox::Error, "#{process["name"]} is pinned to server #{id}, which is not on #{session.app.label}'s cluster" if found.nil?

    Hatchbox::FixedPicker.new(found)
  end
end

class Hatchbox::Journal
  META = /([\\^$.|?*+()\[\]{}])/.freeze

  def initialize(app_name:, process_name: nil, lines: 100, follow: false, since: nil, units_only: false)
    @app_name = app_name.to_s
    @process_name = process_name.to_s
    @lines = lines
    @follow = follow
    @since = since
    @units_only = units_only
  end

  def script
    [
      "set -u",
      "list() { systemctl \"$@\" list-units --type=service --all --plain --no-legend --no-pager 2>/dev/null | awk '{print $1}'; }",
      "scope=system",
      "names=$(list)",
      "units=$(printf '%s\\n' \"$names\" | grep -iE #{quote(primary)} || true)",
      "if [ -z \"$units\" ]; then units=$(printf '%s\\n' \"$names\" | grep -iE #{quote(secondary)} || true); fi",
      "if [ -z \"$units\" ]; then",
      "  scope=user",
      "  names=$(list --user)",
      "  units=$(printf '%s\\n' \"$names\" | grep -iE #{quote(primary)} || true)",
      "  if [ -z \"$units\" ]; then units=$(printf '%s\\n' \"$names\" | grep -iE #{quote(secondary)} || true); fi",
      "fi",
      "if [ -z \"$units\" ]; then",
      "  echo #{quote(miss)} >&2",
      "  echo 'services on this server:' >&2",
      "  list >&2",
      "  list --user >&2",
      "  exit 1",
      "fi",
      "args=''",
      "for u in $units; do args=\"$args -u $u\"; done",
      units_only ? report : tail
    ].join("\n")
  end

  private

  attr_reader :app_name, :process_name, :lines, :follow, :since, :units_only

  def report
    [
      "echo \"scope $scope\"",
      "printf '%s\\n' $units"
    ].join("\n")
  end

  def tail
    [
      "echo unit $units >&2",
      "if [ \"$scope\" = user ]; then",
      "  exec journalctl --user $args #{flags}",
      "fi",
      "probe=$(journalctl -n 1 --no-pager $args 2>&1 || true)",
      "case \"$probe\" in",
      "  *'No journal files'*|*'Permission denied'*|*'systemd-journal'*) exec sudo journalctl $args #{flags} ;;",
      "  *) exec journalctl $args #{flags} ;;",
      "esac"
    ].join("\n")
  end

  def flags
    parts = ["-n", lines.to_s]
    parts.concat(["--since", Shellwords.escape(since)]) unless Hatchbox.blank?(since)
    parts << (follow ? "-f" : "--no-pager")
    parts.join(" ")
  end

  def primary
    return "^.*#{safe(app_name)}.*\\.service$" if process_name.empty?

    "^(.*#{safe(app_name)}.*#{safe(process_name)}|.*#{safe(process_name)}.*#{safe(app_name)}).*\\.service$"
  end

  def secondary
    return "^.*#{safe(app_name)}.*\\.service$" if process_name.empty?

    "^.*#{safe(process_name)}.*\\.service$"
  end

  def miss
    wanted = process_name.empty? ? app_name : "#{app_name} and #{process_name}"
    "no systemd service on this server has #{wanted} in its name, so there is no journal to read"
  end

  def safe(text)
    text.gsub(META) { "\\#{Regexp.last_match(1)}" }
  end

  def quote(text)
    Shellwords.escape(text)
  end
end

module Hatchbox::Registry
  COMMANDS = {}
  ALIASES = {}

  class << self
    def add(klass)
      COMMANDS[klass.meta[:name]] = klass
      klass.meta[:aliases].each { |name| ALIASES[name] = klass.meta[:name] }
    end

    def find(name)
      COMMANDS[name] || COMMANDS[ALIASES[name]]
    end

    def visible
      COMMANDS.values.reject { |klass| klass.meta[:hidden] }
    end
  end
end

class Hatchbox::Command
  APP_FLAGS = [
    ["-a", "--app APP", "app to run command against"],
    ["-r", "--remote REMOTE", "environment in .hatchbox to run command against"]
  ].freeze


  class << self
    attr_reader :meta

    def describe(name, summary:, usage: nil, flags: [], aliases: [], app: true, hidden: false, lenient: false)
      @meta = {
        name: name,
        summary: summary,
        usage: usage || name,
        flags: flags,
        aliases: aliases,
        app: app,
        hidden: hidden,
        lenient: lenient
      }
      Hatchbox::Registry.add(self)
    end

    def call(session:, args:)
      new(session: session, args: args).call
    end
  end

  def initialize(session:, args:)
    @session = session
    @args = args
  end

  private

  attr_reader :session, :args

  def meta
    self.class.meta
  end

  def options
    parse!
    @options
  end

  def positionals
    parse!
    @positionals
  end

  def passthru
    parse!
    @passthru
  end

  def parse!
    return if @parsed

    @parsed = true
    @options = {}
    @positionals = []
    cut = args.index("--")
    head = cut ? args[0, cut] : args.dup
    @passthru = cut ? args[(cut + 1)..-1] : []
    parser = build_parser
    until head.empty?
      begin
        parser.order!(head) { |arg| @positionals << arg }
      rescue OptionParser::InvalidOption => e
        raise Hatchbox::Error, "unknown option for #{meta[:name]}: #{e.args.join(" ")}, see hatchbox help #{meta[:name]}" unless meta[:lenient]

        @positionals.concat(e.args)
      end
    end
  rescue OptionParser::MissingArgument => e
    raise Hatchbox::Error, "#{e.args.join(" ")} needs a value"
  rescue OptionParser::ParseError => e
    raise Hatchbox::Error, e.message
  end

  def build_parser
    parser = OptionParser.new
    parser.require_exact = true
    meta[:flags].each do |short, long, _description, type|
      key = flag_key(long)
      spec = [short, long, type == :many ? nil : type].compact
      negated = long.start_with?("--no-")
      parser.on(*spec) do |value|
        if type == :many
          (@options[key] ||= []) << value
        else
          @options[key] = negated ? true : value
        end
      end
    end
    parser
  end

  def flag_key(long)
    long.sub(/\A--(\[no-\])?/, "").split(/[ =]/).first.tr("-", "_").to_sym
  end

  def usage_error(message)
    raise Hatchbox::Error, "#{message}\n\nusage: hatchbox #{meta[:usage]}"
  end

  def client
    session.client
  end

  def app
    session.app
  end

  def app_id
    session.app_id
  end

  def config
    session.config
  end

  def env
    session.env
  end

  def prompt
    session.prompt
  end

  def label
    app.label
  end

  def ui
    Hatchbox::Ui
  end

  def stream_for(log_id)
    Hatchbox::LogStream.new(client: client, app: app, log_id: log_id)
  end

  def follow_log(log_id)
    stream_for(log_id).follow ? 0 : 1
  end

  def show_log(log_id)
    stream_for(log_id).show ? 0 : 1
  end

  def remember_log(kind, log_id)
    return if env.nil? || !config.exists?

    config.set(key: "last_#{kind}:#{env}", value: log_id)
  end

  def settle(message, log_id, kind: nil)
    if Hatchbox.blank?(log_id)
      puts(message)
      return 0
    end

    remember_log(kind, log_id) if kind
    puts("#{message}, log #{log_id.to_s.cyan}")
    puts
    follow_log(log_id)
  end

  def one_positional(what)
    usage_error("#{meta[:name]} needs a #{what}") if positionals.empty?
    usage_error("one #{what} at a time, #{meta[:name]} got #{positionals.join(" ")}") if positionals.length > 1

    positionals.first
  end

  def confirm(expected:, action:)
    ui.confirm(expected: expected, supplied: options[:confirm], action: action)
  end

  def ssh_run(argv)
    Hatchbox.run(argv)
  end
end

class Hatchbox::Command
  class << self
    def call(session:, args:)
      command = new(session: session, args: args)
      command.send(:prepare)
      command.call
    end
  end

  private

  def prepare
    return unless meta[:app]

    wanted = positional_app
    @session = Hatchbox::Session.new(app_flag: wanted, remote_flag: session.remote_flag) if wanted && Hatchbox.blank?(session.app_flag)
    session.target
  end

  def positional_app
    nil
  end

  def none!
    usage_error("#{meta[:name]} takes no arguments, got #{positionals.join(" ")}") if positionals.any?
  end
end

class Hatchbox::AuthLogin < Hatchbox::Command
  describe "auth:login",
    summary: "log in with a hatchbox api token",
    aliases: ["login"],
    app: false,
    flags: [[nil, "--token TOKEN", "use this token instead of asking for one, which puts it in your shell history"]]

  def call
    none!
    store = Hatchbox::TokenStore.new(prompt: prompt)
    token = Hatchbox.blank?(options[:token]) ? store.ask : options[:token]
    probe = Hatchbox::Client.new(token: token)
    response = probe.raw("GET", "/accounts")
    raise Hatchbox::Error, probe.error_message(response) unless response.ok?

    store.save(token)
    names = (response.json || []).map { |account| account["name"] }
    puts("logged in, the token reaches #{names.join(", ")}".green)
    puts("saved it to #{store.path}".dim)
    warn("HATCHBOX_API_TOKEN is set and wins over #{store.path} until you unset it".yellow) unless Hatchbox.blank?(ENV["HATCHBOX_API_TOKEN"])
    0
  end
end

class Hatchbox::AuthLogout < Hatchbox::Command
  describe "auth:logout",
    summary: "clear the saved api token",
    aliases: ["logout"],
    app: false

  def call
    none!
    store = Hatchbox::TokenStore.new(prompt: prompt)
    removed = store.forget
    puts(removed.zero? ? "no token saved in #{store.path}, nothing to do" : "took the token out of #{store.path}")
    warn("HATCHBOX_API_TOKEN is still set, so commands keep working until you unset it".yellow) unless Hatchbox.blank?(ENV["HATCHBOX_API_TOKEN"])
    0
  end
end

class Hatchbox::AuthToken < Hatchbox::Command
  describe "auth:token",
    summary: "display the api token in use",
    app: false

  def call
    none!
    puts(session.token)
    0
  end
end

class Hatchbox::AuthWhoami < Hatchbox::Command
  describe "auth:whoami",
    summary: "display the accounts the api token can reach",
    aliases: ["whoami"],
    app: false

  def call
    none!
    accounts = client.get("/accounts").json || []
    puts("the token reaches")
    accounts.each { |account| puts("  #{account["name"]}, account #{account["id"]}") }
    puts("token from #{Hatchbox::TokenStore.new.source(env: session.remote_flag)}".dim)
    0
  end
end

class Hatchbox::AppsList < Hatchbox::Command
  describe "apps",
    summary: "list your apps",
    usage: "apps",
    aliases: ["apps:list", "list"],
    app: false

  def call
    none!
    catalog = session.catalog
    accounts = catalog.accounts
    rows = catalog.entries

    clusters = cluster_names(accounts: accounts, catalog: catalog)
    shown = 0
    accounts.each do |account|
      mine = rows.select { |row| row[:account_record]["id"].to_s == account["id"].to_s }
      next if mine.empty?

      puts if shown.positive?
      ui.header("apps on #{account["name"]}")
      mine.each { |row| puts("  #{row[:slug].ljust(34)} #{clusters[row[:cluster_id]] || "cluster #{row[:cluster_id]}"}") }
      shown += 1
    end
    puts("no apps on any account the token reaches") if shown.zero?
    catalog.skipped.each { |name, message| warn("skipping #{name}, #{message}".yellow) }
    0
  end

  private

  def cluster_names(accounts:, catalog:)
    usable = accounts.reject { |account| catalog.skipped.key?(account["name"].to_s) }
    found = Hatchbox.parallel(usable.to_h { |account| [account["id"].to_s, -> { catalog.clusters_for(account) }] })
    found.values.flatten.to_h { |cluster| [cluster["id"].to_s, cluster["name"].to_s] }
  end
end

class Hatchbox::AppsInfo < Hatchbox::Command
  EXTENDED = [
    ["pre build script", "pre_build_script"],
    ["build script", "build_script"],
    ["post build script", "post_build_script"],
    ["post deploy script", "post_deploy_script"],
    ["failed deploy script", "failed_deploy_script"],
    ["caddyfile", "caddyfile"],
    ["dns provider", "dns_provider"],
    ["dns api user", "dns_api_user"]
  ].freeze

  describe "apps:info",
    summary: "show detailed app information",
    usage: "apps:info [APP]",
    aliases: ["info"],
    flags: [["-x", "--extended", "show the deploy scripts, the caddyfile and the dns settings too"], ["-s", "--shell", "output more shell friendly key/value pairs"]]

  def call
    usage_error("one app at a time") if positionals.length > 1
    data = gather
    return shell(data) if options[:shell]

    ui.header("#{data["name"]}, app #{data["id"]}")
    rows = pairs(data)
    width = [rows.map { |key, _value| key.length }.max + 2, 14].max
    puts(rows.map { |key, value| "  #{key.ljust(width)}#{Hatchbox.blank?(value) ? "-" : value}" }.join("\n"))
    0
  end

  private

  def positional_app
    positionals.first
  end

  def gather
    found = Hatchbox.parallel(
      details: -> { app.details },
      cluster: -> { app.cluster },
      processes: -> { app.processes },
      domains: -> { app.domains },
      databases: -> { app.databases },
      account: -> { session.catalog.account_for(app.id) }
    )
    provider = git_provider(account: found[:account], id: found[:details]["connected_account_id"])
    found[:details].merge(
      "cluster" => found[:cluster].reject { |key, _value| key == "servers" },
      "servers" => found[:cluster]["servers"] || [],
      "processes" => found[:processes],
      "domains" => found[:domains].map { |row| row["name"] },
      "databases" => found[:databases].map { |record| record.slice("id", "name", "engine", "database_cluster_id").merge("as" => (record["app_attachments"] || []).select { |row| row["app_id"].to_s == app.id }.map { |row| row["env_var"].to_s }) },
      "team" => found[:account] ? found[:account]["name"] : nil,
      "git_provider" => provider,
      "web_url" => app.web_url
    )
  end

  def git_provider(account:, id:)
    return nil if account.nil? || Hatchbox.blank?(id)

    found = session.catalog.git_providers_for(account).find { |row| row["id"].to_s == id.to_s }
    found ? "#{found["provider"]} #{found["name"]}" : "provider #{id}"
  rescue Hatchbox::Error
    "provider #{id}"
  end

  def pairs(data)
    cluster = data["cluster"] || {}
    rows = [
      ["branch", data["branch"]],
      ["repo", data["repo_path"]],
      ["auto deploy", data["auto_deploy"] ? "on" : "off"],
      ["maintenance", data["maintenance"] ? "on" : "off"],
      ["team", data["team"]],
      ["cluster", cluster["name"]],
      ["servers", data["servers"].map { |server| server["name"] }.join(", ")],
      ["processes", data["processes"].map { |row| row["name"] }.join(", ")],
      ["domains", data["domains"].join(", ")],
      ["web url", data["web_url"]],
      ["databases", data["databases"].map { |record| "#{record["name"]} (#{record["engine"]})#{record["as"].empty? ? "" : " as #{record["as"].join(", ")}"}" }.join(", ")],
      ["git provider", data["git_provider"]],
      ["health check", data["health_check_uri"]],
      ["last deploy", last_deploy(data)]
    ]
    rows.concat(EXTENDED.map { |title, key| [title, data[key]] }) if options[:extended]
    rows
  end

  def last_deploy(data)
    sha = data["last_deploy_sha"].to_s
    return nil if sha.empty?

    [sha[0, 7], data["last_deploy_at"]].compact.join(" at ")
  end

  def shell(data)
    flat = {
      "databases" => data["databases"].map { |record| record["name"] }.join(","),
      "auto_deploy" => data["auto_deploy"],
      "branch" => data["branch"],
      "cluster" => (data["cluster"] || {})["name"],
      "domains" => data["domains"].join(","),
      "git_provider" => data["git_provider"],
      "health_check_uri" => data["health_check_uri"],
      "id" => data["id"],
      "last_deploy_at" => data["last_deploy_at"],
      "last_deploy_sha" => data["last_deploy_sha"],
      "maintenance" => data["maintenance"],
      "name" => data["name"],
      "processes" => data["processes"].map { |row| row["name"] }.join(","),
      "repo_path" => data["repo_path"],
      "servers" => data["servers"].map { |server| server["name"] }.join(","),
      "team" => data["team"],
      "web_url" => data["web_url"]
    }
    flat.each { |key, value| puts("#{key}=#{value}") }
    0
  end
end

class Hatchbox::AppsCreate < Hatchbox::Command
  NAME = /\A[A-Za-z0-9_-]+\z/.freeze

  describe "apps:create",
    summary: "create a new app on a cluster",
    usage: "apps:create NAME",
    aliases: ["create"],
    app: false,
    flags: [
      ["-c", "--cluster CLUSTER", "cluster to create the app on, by name or id"],
      [nil, "--account ACCOUNT", "account the cluster belongs to, by name or id"],
      [nil, "--repo REPO", "repository to deploy, e.g. myuser/my-app"],
      ["-b", "--branch BRANCH", "branch to deploy, main unless you say otherwise"],
      [nil, "--git-provider PROVIDER", "connected git account to deploy from, by name or id"],
      [nil, "--no-remote", "do not add the app to .hatchbox"]
    ]

  def call
    name = positionals.first || session.app_flag
    usage_error("apps:create needs a name") if Hatchbox.blank?(name)
    usage_error("one name at a time, apps:create got #{positionals.join(" ")}") if positionals.length > 1
    raise Hatchbox::Error, "#{name} is not a name hatchbox takes, which is letters, numbers, hyphens and underscores" unless name =~ NAME

    catalog = session.catalog
    account = catalog.find_account(options[:account])
    cluster = pick_cluster(catalog.clusters_for(account))
    body = { "cluster_id" => cluster["id"], "name" => name }
    body["branch"] = options[:branch] unless Hatchbox.blank?(options[:branch])
    body["repo_path"] = options[:repo] unless Hatchbox.blank?(options[:repo])
    body["connected_account_id"] = pick_provider(catalog.git_providers_for(account))["id"] unless Hatchbox.blank?(options[:git_provider])
    created = client.post("/apps", body: { "app" => body }).json || {}
    slug = "#{created["id"]}-#{created["name"] || name}"
    puts("created #{slug.cyan} on #{cluster["name"]}, auto deploy is off")
    remember(slug) unless options[:no_remote]
    0
  end

  private

  def pick_cluster(clusters)
    wanted = options[:cluster]
    if Hatchbox.blank?(wanted)
      return clusters.first if clusters.length == 1
      raise Hatchbox::Error, "that account has no clusters, make one on the dashboard first" if clusters.empty?

      raise Hatchbox::Error, "more than one cluster, so pick one with --cluster\n\n#{listing(clusters)}"
    end

    found = clusters.find { |row| row["id"].to_s == wanted.to_s || row["name"].to_s.casecmp?(wanted.to_s) }
    raise Hatchbox::Error, "no cluster called #{wanted}\n\n#{listing(clusters)}" unless found

    found
  end

  def listing(clusters)
    clusters.map { |row| "  #{row["name"]}, cluster #{row["id"]}" }.join("\n")
  end

  def pick_provider(providers)
    wanted = options[:git_provider].to_s
    found = providers.select { |row| row["id"].to_s == wanted || row["name"].to_s.casecmp?(wanted) || "#{row["provider"]}:#{row["name"]}".casecmp?(wanted) }
    return found.first if found.length == 1

    listing = providers.map { |row| "  #{row["provider"]}:#{row["name"]}, provider #{row["id"]}" }.join("\n")
    raise Hatchbox::Error, "more than one git provider is called #{wanted}, so use provider:name or the id\n\n#{listing}" if found.length > 1

    raise Hatchbox::Error, "no git provider called #{wanted}\n\n#{listing}"
  end

  def remember(slug)
    target = Hatchbox::Config.find || (Hatchbox::Config.repo_root && Hatchbox::Config.target)
    return puts("add it to a .hatchbox with hatchbox git:remote -a #{slug}".dim) unless target

    file = Hatchbox::Config.new(target)
    remote = Hatchbox.blank?(session.remote_flag) ? "production" : session.remote_flag
    existing = file.app_for(remote)
    unless Hatchbox.blank?(existing)
      puts("#{remote} is already #{existing} in #{file.path}, so it was left alone".yellow)
      return
    end

    file.set_app(env: remote, app: slug)
    puts("#{slug} is #{remote} in #{file.path}".green)
  end
end

class Hatchbox::Config
  class << self
    def repo_root
      Pathname.new(Dir.pwd).ascend { |dir| break dir.to_s if dir.join(".git").exist? }
    end
  end
end

class Hatchbox::AppsDestroy < Hatchbox::Command
  describe "apps:destroy",
    summary: "permanently destroy an app",
    usage: "apps:destroy [APP]",
    aliases: ["destroy"],
    flags: [[nil, "--confirm APP", "the app's name, to skip the prompt"]]

  def call
    usage_error("one app at a time") if positionals.length > 1
    name = app.name
    confirm(expected: name, action: "this destroys #{name}, its folder and services on every server")
    client.delete("/apps/#{app_id}", body: { "name" => name })
    puts("destroying #{name.cyan}, its databases are detached, not deleted")
    gone = config.remove_app_id(app_id)
    puts("took #{ui.list(gone)} out of #{config.path}".dim) if gone.any?
    0
  end

  private

  def positional_app
    positionals.first
  end
end

class Hatchbox::AppsRename < Hatchbox::Command
  describe "apps:rename",
    summary: "rename an app, which takes it down while it moves",
    usage: "apps:rename NEWNAME",
    aliases: ["rename"],
    flags: [[nil, "--confirm APP", "the app's current name, to skip the prompt"]]

  def call
    new_name = one_positional("new name")
    raise Hatchbox::Error, "#{new_name} is not a name hatchbox takes, which is letters, numbers, hyphens and underscores" unless new_name =~ Hatchbox::AppsCreate::NAME

    old = app.name
    raise Hatchbox::Error, "#{old} is already called that" if new_name == old

    confirm(expected: old, action: "renaming #{old} stops its processes and moves its folder, so it is down until it finishes")
    client.post("/apps/#{app_id}/rename", body: { "app" => { "name" => new_name } })
    puts("renaming #{old.cyan} to #{new_name.cyan}")
    moved = config.rename_app_id(app_id: app_id, slug: "#{app_id}-#{new_name}")
    moved.each { |remote| puts("#{remote} in #{config.path} follows it".dim) }
    0
  end
end

class Hatchbox::AppsOpen < Hatchbox::Command
  describe "apps:open",
    summary: "open the app in a web browser",
    usage: "apps:open [PATH]",
    aliases: ["open"]

  def call
    usage_error("one path at a time, apps:open got #{positionals.join(" ")}") if positionals.length > 1
    base = app.web_url
    raise Hatchbox::Error, "#{label} has no domains, so there is nothing to open. add one on the dashboard" unless base

    url = "#{base.chomp("/")}/#{positionals.first.to_s.sub(%r{\A/}, "")}"
    opener = RbConfig::CONFIG["host_os"] =~ /darwin/ ? "open" : "xdg-open"
    warn("opening #{url}".dim)
    Hatchbox.run([opener, url])
  end
end

class Hatchbox::AppsUpdate < Hatchbox::Command
  FIELDS = {
    branch: "branch",
    repo: "repo_path",
    pre_build_script: "pre_build_script",
    build_script: "build_script",
    post_build_script: "post_build_script",
    post_deploy_script: "post_deploy_script",
    failed_deploy_script: "failed_deploy_script",
    health_check: "health_check_uri",
    dns_provider: "dns_provider",
    dns_api_user: "dns_api_user",
    dns_access_token: "dns_access_token"
  }.freeze

  describe "apps:update",
    summary: "change an app's branch, repo, deploy scripts or caddy settings",
    flags: [
      ["-b", "--branch BRANCH", "branch to deploy"],
      [nil, "--repo REPO", "repository to deploy, e.g. myuser/my-app"],
      [nil, "--git-provider PROVIDER", "connected git account to deploy from, by name or id"],
      [nil, "--pre-build-script SCRIPT", "script run before the build, or @FILE to read it from a file"],
      [nil, "--build-script SCRIPT", "build script, or @FILE"],
      [nil, "--post-build-script SCRIPT", "script run after the build, or @FILE"],
      [nil, "--post-deploy-script SCRIPT", "script run after the deploy, or @FILE"],
      [nil, "--failed-deploy-script SCRIPT", "script run once when a deploy fails, or @FILE"],
      [nil, "--health-check PATH", "relative path for caddy to health check, e.g. /up"],
      [nil, "--caddyfile FILE", "caddyfile to apply, or - to read it from stdin"],
      [nil, "--dns-provider PROVIDER", "dns provider for certificates"],
      [nil, "--dns-api-user USER", "dns api user"],
      [nil, "--dns-access-token TOKEN", "dns access token, which hatchbox never returns"]
    ]

  def call
    none!
    body = {}
    FIELDS.each { |flag, field| body[field] = expand(options[flag]) if options.key?(flag) }
    body["caddyfile"] = caddyfile(options[:caddyfile]) if options.key?(:caddyfile)
    body["connected_account_id"] = provider_id(options[:git_provider]) if options.key?(:git_provider)
    usage_error("apps:update needs something to change") if body.empty?
    raise Hatchbox::Error, "--health-check takes a relative path like /up" if body.key?("health_check_uri") && !body["health_check_uri"].to_s.start_with?("/")

    client.patch("/apps/#{app_id}", body: { "app" => body })
    puts("updated #{label.cyan}, #{body.keys.join(", ")}")
    puts("caddy is being reapplied on the servers".dim) if body.key?("caddyfile") || body.key?("health_check_uri")
    0
  end

  private

  def expand(value)
    text = value.to_s
    return text unless text.start_with?("@")

    File.read(text[1..-1])
  rescue Errno::ENOENT
    raise Hatchbox::Error, "no file at #{text[1..-1]}"
  end

  def caddyfile(path)
    return $stdin.read if path == "-"

    File.read(path)
  rescue Errno::ENOENT
    raise Hatchbox::Error, "no file at #{path}"
  end

  def provider_id(wanted)
    account = session.catalog.account_for(app_id)
    raise Hatchbox::Error, "could not tell which account #{label} is on" unless account

    providers = session.catalog.git_providers_for(account)
    found = providers.select { |row| row["id"].to_s == wanted.to_s || row["name"].to_s.casecmp?(wanted.to_s) || "#{row["provider"]}:#{row["name"]}".casecmp?(wanted.to_s) }
    return found.first["id"] if found.length == 1

    raise Hatchbox::Error, "could not pick a git provider from #{wanted}\n\n#{providers.map { |row| "  #{row["provider"]}:#{row["name"]}, provider #{row["id"]}" }.join("\n")}"
  end
end

class Hatchbox::Remotes < Hatchbox::Command
  describe "remotes",
    summary: "list the apps named in .hatchbox",
    aliases: ["envs", "git:remotes"],
    app: false

  def call
    none!
    raise Hatchbox::Error, "no .hatchbox here or above #{Dir.pwd}, add one with hatchbox git:remote" unless config.exists?

    puts("remotes in #{config.path}")
    current = begin
      session.target.env
    rescue Hatchbox::Error
      nil
    end
    config.apps.each do |name, slug|
      puts("  #{name}, app #{slug}#{name == current ? " (in use)".green : ""}")
    end
    0
  end
end

class Hatchbox::GitRemote < Hatchbox::Command
  describe "git:remote",
    summary: "add an app to .hatchbox, the way heroku adds a git remote",
    usage: "git:remote [FILTER]",
    aliases: ["setup"],
    app: false,
    flags: [[nil, "--as REMOTE", "the remote name, same as -r"]]

  def call
    usage_error("one filter at a time") if positionals.length > 1
    Hatchbox::TokenStore.new(prompt: prompt).ensure_token
    @file = Hatchbox::Config.new(Hatchbox::Config.target)
    slug = Hatchbox.blank?(session.app_flag) ? choose_app(positionals.first) : resolve(session.app_flag)
    remote = options[:as] || session.remote_flag
    remote = ask_remote(guess_remote(slug)) if Hatchbox.blank?(remote)
    validate(remote)
    return 1 unless replace?(remote: remote, slug: slug)

    write(remote: remote, slug: slug)
    0
  end

  private

  attr_reader :file

  def resolve(value)
    lookup = Hatchbox::Session.new(app_flag: value)
    "#{lookup.app_id}-#{lookup.app.name}"
  end

  def choose_app(filter)
    rows = session.catalog.entries(filter: filter)
    raise Hatchbox::Error, empty_message(filter) if rows.empty?

    matched = rows.select { |row| repos.include?(normalize(row[:record]["repo_path"])) }
    if matched.length == 1
      puts("found #{matched.first[:slug]}, which deploys #{matched.first[:record]["repo_path"]}")
      return matched.first[:slug]
    end
    unless prompt.available?
      raise Hatchbox::Error, "more than one app deploys this repo, so pick one with -a\n\n#{matched.map { |row| "  #{row[:slug]}" }.join("\n")}" if matched.any?

      raise Hatchbox::Error, "git:remote needs a terminal, or pass -a APP and -r REMOTE"
    end

    pool = matched.any? ? matched : rows
    puts
    puts(matched.any? ? "apps that deploy this repo" : "apps this token can see")
    pool.each_with_index { |row, index| puts(format("  %2d  %-34s %s", index + 1, row[:slug], row[:account])) }
    puts
    pool[prompt.ask_number(question: "which one? ", count: pool.length) - 1][:slug]
  end

  def repos
    @repos ||= begin
      output, status = Open3.capture2("git", "config", "--get-regexp", "^remote\\..*\\.url$", err: File::NULL)
      status.success? ? output.lines.map { |line| normalize(line.split(" ", 2).last) }.compact.uniq : []
    rescue Errno::ENOENT
      []
    end
  end

  def normalize(url)
    text = url.to_s.strip.sub(/\.git\z/, "").sub(%r{/+\z}, "")
    text = text.sub(%r{\A[a-z][a-z0-9+.-]*://}i, "")
    text = text.sub(%r{\A[^@/]+@}, "")
    text = text.sub(%r{\A[^/:]*\.[^/:]*(:[0-9]+)?[:/]}, "")
    text = text.sub(%r{\A/}, "")
    text.empty? ? nil : text.downcase
  end

  def empty_message(filter)
    Hatchbox.blank?(filter) ? "the token can see no apps at all" : "no app matches #{filter}"
  end

  def guess_remote(slug)
    found = Hatchbox.slug_name(slug)[/[-_](production|prod|staging|stage|qa|dev|development|test|demo|preview)\z/i, 1].to_s.downcase
    { "" => "production", "prod" => "production", "stage" => "staging", "dev" => "development" }.fetch(found, found)
  end

  def ask_remote(suggested)
    return suggested unless prompt.available?

    answer = prompt.ask(question: "call it what, here? [#{suggested}] ")
    Hatchbox.blank?(answer) ? suggested : answer
  end

  def validate(remote)
    return unless remote =~ /[:=\s]/

    raise Hatchbox::Error, "a remote name cannot hold a colon, an equals or a space"
  end

  def replace?(remote:, slug:)
    existing = file.exists? ? file.app_for(remote) : nil
    return true if Hatchbox.blank?(existing) || existing == slug

    puts
    puts("#{remote} is already #{existing} in #{file.path}".yellow)
    return true unless prompt.available? && Hatchbox.blank?(ENV["HATCHBOX_ASSUME_YES"])
    return true if ["y", "yes"].include?(prompt.ask(question: "point it at #{slug} instead? [y/N] ").to_s.downcase)

    puts("left alone")
    false
  end

  def write(remote:, slug:)
    file.set_app(env: remote, app: slug)
    puts
    puts("#{slug} is #{remote} in #{file.path}".green)
    choose_default
    report
  end

  def choose_default
    remotes = file.envs
    return if remotes.length < 2 || !Hatchbox.blank?(file.get("default"))

    puts
    puts("there is more than one remote here now, so every command wants -r")
    puts("unless one of them is the default")
    return unless prompt.available?

    set_default(remotes, prompt.ask(question: "which should it be? (blank to always pass -r) "))
  end

  def set_default(remotes, answer)
    return if Hatchbox.blank?(answer)
    return puts("no remote called #{answer}, leaving the default unset".yellow) unless remotes.include?(answer)

    file.set(key: "default", value: answer)
    puts("default is #{answer}".green)
  end

  def report
    puts
    puts("remotes in #{file.path}")
    file.apps.each { |remote, slug| puts("  #{remote}, app #{slug}") }
  end
end

class Hatchbox::ConfigShow < Hatchbox::Command
  describe "config",
    summary: "display the config vars set on an app",
    aliases: ["config:list"]

  def call
    none!
    names = app.env_var_names
    if names.empty?
      puts("no env vars on #{label}, set one with config:set FOO=bar")
      return 0
    end

    puts("env vars on #{label.cyan}, names only since hatchbox never hands a value back")
    names.each { |name| puts("  #{name}") }
    0
  end
end

class Hatchbox::ConfigGet < Hatchbox::Command
  describe "config:get",
    summary: "check whether a config var is set",
    usage: "config:get KEY"

  def call
    key = one_positional("name").upcase
    raise Hatchbox::Error, "#{key} is set on #{label}, but hatchbox never hands the value back" if app.env_var_names.include?(key)

    raise Hatchbox::Error, "#{key} is not set on #{label}"
  end
end

class Hatchbox::ConfigSet < Hatchbox::Command
  USABLE = /\A[A-Z0-9_]+\z/.freeze

  describe "config:set",
    summary: "set one or more config vars",
    usage: "config:set KEY1=VALUE1 [KEY2=VALUE2 ...]"

  def call
    usage_error("config:set takes NAME=VALUE, one or more of them") if positionals.empty?
    vars = positionals.map { |pair| pair_for(pair) }
    names = vars.map { |var| var["name"] }
    client.put("/apps/#{app_id}/env_vars", body: { "env_vars" => vars })
    puts("set #{names.join(", ").cyan} on #{label}")
    puts("hatchbox pushes that to the servers itself and hands back no log id, so there is nothing to follow".dim)
    0
  end

  private

  def pair_for(text)
    name, separator, value = text.partition("=")
    usage_error("#{text} is not NAME=VALUE") if separator.empty? || name.empty?

    { "name" => Hatchbox::ConfigSet.usable(name), "value" => value }
  end

  def self.usable(name)
    cleaned = name.strip.upcase
    raise Hatchbox::Error, "#{name} is not a name hatchbox takes, which is letters, numbers and underscores" unless cleaned =~ USABLE

    cleaned
  end
end

class Hatchbox::ConfigUnset < Hatchbox::Command
  describe "config:unset",
    summary: "unset one or more config vars",
    usage: "config:unset KEY1 [KEY2 ...]",
    aliases: ["config:remove"]

  def call
    usage_error("config:unset takes a name, one or more of them") if positionals.empty?
    names = positionals.map { |name| Hatchbox::ConfigSet.usable(name) }
    client.delete("/apps/#{app_id}/env_vars", body: { "env_vars" => names })
    puts("unset #{names.join(", ").cyan} on #{label}")
    puts("hatchbox pushes that to the servers itself and hands back no log id, so there is nothing to follow".dim)
    0
  end
end

class Hatchbox::Maintenance < Hatchbox::Command
  describe "maintenance",
    summary: "display the current maintenance status of an app"

  def call
    none!
    puts(app.details["maintenance"] ? "on" : "off")
    0
  end
end

class Hatchbox::MaintenanceOn < Hatchbox::Command
  describe "maintenance:on",
    summary: "put the app into maintenance mode"

  def call
    none!
    client.post("/apps/#{app_id}/maintenance")
    puts("maintenance mode on for #{label.cyan}")
    puts("caddy serves the maintenance page, the processes keep running".dim)
    0
  end
end

class Hatchbox::MaintenanceOff < Hatchbox::Command
  describe "maintenance:off",
    summary: "take the app out of maintenance mode"

  def call
    none!
    client.delete("/apps/#{app_id}/maintenance")
    puts("maintenance mode off for #{label.cyan}")
    0
  end
end

class Hatchbox::GitProviders < Hatchbox::Command
  describe "git:providers",
    summary: "list the connected git accounts apps can deploy from",
    app: false

  def call
    none!
    catalog = session.catalog
    accounts = catalog.usable_accounts
    found = accounts.to_h { |account| [account, catalog.git_providers_for(account)] }

    found.each_with_index do |(account, rows), index|
      puts if index.positive?
      ui.header("git providers on #{account["name"]}")
      next puts("  none connected") if rows.empty?

      rows.each { |row| puts("  #{row["provider"].to_s.ljust(10)} #{row["name"].to_s.ljust(24)} #{row["id"]}") }
    end
    0
  end
end

class Hatchbox::PsCommand < Hatchbox::Command
  private

  def catalog
    @catalog ||= Hatchbox::ProcessCatalog.new(client: client, app_id: app_id)
  end

  def process_path(process, suffix = nil)
    base = "/apps/#{app_id}/processes/#{process["id"]}"
    suffix ? "#{base}/#{suffix}" : base
  end
end

class Hatchbox::Ps < Hatchbox::PsCommand
  describe "ps",
    summary: "list processes for an app",
    usage: "ps [TYPE [TYPE ...]]"

  def call
    pool = positionals.empty? ? catalog.all : positionals.map { |name| catalog.find(name) }
    if pool.empty?
      puts("no processes on #{label}, add one with ps:create")
      return 0
    end

    puts("processes on #{label.cyan}, app #{app_id}")
    puts
    puts(catalog.table(pool.sort_by { |row| row["name"].to_s }))
    0
  end
end

class Hatchbox::PsInfo < Hatchbox::PsCommand
  describe "ps:info",
    summary: "show everything about one process",
    usage: "ps:info TYPE"

  def call
    process = catalog.find(one_positional("process"))

    puts("#{process["name"].to_s.cyan}, process #{process["id"]} on #{label}")
    puts
    puts(Hatchbox::ProcessCatalog.detail(process))
    0
  end
end

class Hatchbox::PsRestart < Hatchbox::PsCommand
  describe "ps:restart",
    summary: "restart every process, or one process type",
    usage: "ps:restart [TYPE]",
    aliases: ["restart"]

  def call
    usage_error("one process at a time, ps:restart got #{positionals.join(" ")}") if positionals.length > 1
    if positionals.empty?
      log_id = (client.post("/apps/#{app_id}/restart").json || {})["id"]
      return settle("queued restart of every process on #{label.cyan}", log_id, kind: "restart")
    end

    process = catalog.find(positionals.first)
    log_id = (client.post(process_path(process, "restart")).json || {})["id"]
    settle("queued restart of #{process["name"].to_s.cyan} on #{label}", log_id, kind: "restart")
  end
end

class Hatchbox::PsStop < Hatchbox::PsCommand
  describe "ps:stop",
    summary: "turn a process off and leave it off",
    usage: "ps:stop TYPE",
    aliases: ["ps:kill"]

  def call
    process = catalog.find(one_positional("process"))
    data = client.delete(process_path(process, "activation")).json || {}
    settle("disabled #{process["name"].to_s.cyan} on #{label}", data["log_id"])
  end
end

class Hatchbox::PsStart < Hatchbox::PsCommand
  describe "ps:start",
    summary: "turn a stopped process back on",
    usage: "ps:start TYPE"

  def call
    process = catalog.find(one_positional("process"))
    data = client.post(process_path(process, "activation")).json || {}
    settle("enabled #{process["name"].to_s.cyan} on #{label}", data["log_id"])
  end
end

module Hatchbox::ProcessFields
  FLAGS = [
    [nil, "--name NAME", "process name, letters, numbers, hyphens and underscores"],
    [nil, "--start COMMAND", "the command that runs"],
    [nil, "--stop COMMAND", "command systemd runs to stop it"],
    [nil, "--reload COMMAND", "command systemd runs to reload it"],
    [nil, "--roles LIST", "comma separated roles, it runs on every server holding one"],
    [nil, "--server SERVER", "one server to run on instead of roles, by name or id"],
    [nil, "--systemd-type TYPE", "simple or oneshot"],
    [nil, "--[no-]socket", "systemd socket activation, at most one process per app"],
    [nil, "--[no-]restart-on-deploy", "restart it on every deploy, which is the default"],
    [nil, "--[no-]appsignal", "run it under appsignal-wrap, which needs appsignal connected"],
    [nil, "--appsignal-options OPTIONS", "extra flags for appsignal-wrap"]
  ].freeze

  MAP = {
    name: "name",
    start: "start_command",
    stop: "stop_command",
    reload: "reload_command",
    systemd_type: "systemd_type",
    socket: "socket",
    restart_on_deploy: "restart_on_deploy",
    appsignal: "appsignal",
    appsignal_options: "appsignal_options"
  }.freeze

  private

  def process_body
    body = {}
    MAP.each { |flag, field| body[field] = options[flag] if options.key?(flag) }
    body["roles"] = options[:roles].split(",").map { |role| role.strip }.reject { |role| role.empty? } if options.key?(:roles)
    body["server_id"] = server_id_for(options[:server]) if options.key?(:server)
    raise Hatchbox::Error, "a process runs on --roles or on one --server, not both" if body.key?("roles") && body.key?("server_id") && body["roles"].any?
    raise Hatchbox::Error, "#{body["name"]} is not a name hatchbox takes, which is letters, numbers, hyphens and underscores" if body.key?("name") && body["name"] !~ Hatchbox::ProcessCatalog::NAME

    body
  end

  def server_id_for(wanted)
    return wanted if wanted.to_s =~ /\A[0-9]+\z/

    found = app.servers.find { |server| server["name"].to_s.casecmp?(wanted.to_s) }
    raise Hatchbox::Error, "no server called #{wanted} on #{label}'s cluster" unless found

    found["id"]
  end

  def show(process)
    puts(Hatchbox::ProcessCatalog.detail(process))
  end
end

class Hatchbox::PsCreate < Hatchbox::PsCommand
  include Hatchbox::ProcessFields

  describe "ps:create",
    summary: "add a process to the app",
    usage: "ps:create NAME --start COMMAND (--roles LIST | --server SERVER)",
    flags: Hatchbox::ProcessFields::FLAGS

  def call
    usage_error("ps:create takes one name") if positionals.length > 1
    body = process_body
    body["name"] = positionals.first if positionals.any? && Hatchbox.blank?(body["name"])
    usage_error("ps:create needs --name") if Hatchbox.blank?(body["name"])
    usage_error("ps:create needs --start, the command that runs") if Hatchbox.blank?(body["start_command"])
    usage_error("ps:create needs --roles or --server, so hatchbox knows where to run it") if Array(body["roles"]).empty? && Hatchbox.blank?(body["server_id"])
    raise Hatchbox::Error, "#{body["name"]} is not a name hatchbox takes, which is letters, numbers, hyphens and underscores" unless body["name"] =~ Hatchbox::ProcessCatalog::NAME

    data = client.post("/apps/#{app_id}/processes", body: { "process" => body }).json || {}
    code = settle("created #{body["name"].to_s.cyan} on #{label}, process #{data["id"]}", data["log_id"])
    puts
    show(data)
    code
  end
end

class Hatchbox::PsUpdate < Hatchbox::PsCommand
  include Hatchbox::ProcessFields

  describe "ps:update",
    summary: "change a process",
    usage: "ps:update TYPE [--start COMMAND] [--roles LIST] ...",
    flags: Hatchbox::ProcessFields::FLAGS

  def call
    process = catalog.find(one_positional("process"))
    body = process_body
    usage_error("ps:update needs something to change") if body.empty?

    data = client.patch(process_path(process), body: { "process" => body }).json || {}
    settle("updated #{process["name"].to_s.cyan} on #{label}, #{body.keys.join(", ")}", data["log_id"])
  end
end

class Hatchbox::PsDestroy < Hatchbox::PsCommand
  describe "ps:destroy",
    summary: "stop a process and delete it from every server",
    usage: "ps:destroy TYPE",
    flags: [[nil, "--confirm TYPE", "the process name, to skip the prompt"]]

  def call
    process = catalog.find(one_positional("process"))
    name = process["name"].to_s
    confirm(expected: name, action: "this deletes #{name} on #{label}")
    log_id = (client.delete(process_path(process)).json || {})["id"]
    settle("deleted #{name.cyan} on #{label}", log_id)
  end
end

class Hatchbox::Logs < Hatchbox::Command
  describe "logs",
    summary: "display recent log output",
    flags: [
      ["-n", "--num NUM", "number of lines to display", Integer],
      ["-t", "--tail", "continually stream logs"],
      ["-f", "--follow", "same as --tail"],
      ["-p", "--process-type TYPE", "only this process type"],
      [nil, "--ps TYPE", "same as --process-type"],
      ["-s", "--server SERVER", "the server to read, by name or role"],
      [nil, "--since WHEN", "only lines since this, anything journalctl --since takes, like '1 hour ago'"],
      [nil, "--units", "list the systemd units it would read, and stop"]
    ]

  def call
    usage_error("one process at a time") if positionals.length > 1
    wanted = positionals.first
    raise Hatchbox::Error, "logs reads the running app now. a hatchbox log id goes to releases:output #{wanted}" if wanted.to_s =~ /\A[0-9]+\z/

    type = options[:process_type] || options[:ps] || wanted
    process = Hatchbox.blank?(type) ? nil : catalog.find(type)
    target = Hatchbox::ProcessTarget.resolve(session: session, process: process, filter: options[:server])
    warn("#{process ? process["name"] : "every process"} on #{target.server_label || target.host}, journal on the server, hatchbox stores none of this".dim)
    Hatchbox.run(target.ssh(command: target.login_shell(journal(process)), tty: $stdout.tty?))
  end

  private

  def journal(process)
    Hatchbox::Journal.new(
      app_name: app.name,
      process_name: process ? process["name"] : nil,
      lines: options[:num] || 100,
      follow: options[:tail] || options[:follow],
      since: options[:since],
      units_only: options[:units]
    ).script
  end

  def catalog
    @catalog ||= Hatchbox::ProcessCatalog.new(client: client, app_id: app_id)
  end
end

class Hatchbox::Run < Hatchbox::Command
  describe "run",
    summary: "run a command on one of the app's servers",
    usage: "run COMMAND",
    lenient: true,
    flags: [["-s", "--server SERVER", "the server to run on, by name or role"]]

  def call
    command = (positionals + passthru).join(" ")
    usage_error("run needs a command") if command.strip.empty?

    target = Hatchbox::SshTarget.resolve(session: session, filter: options[:server])
    Hatchbox.run(target.ssh(command: target.login_shell(script_for(command: command, target: target)), tty: $stdin.tty? && $stdout.tty?))
  end

  private

  def rails?(command)
    ["rails", "bin/rails"].include?(command) || command.start_with?("rails ", "bin/rails ")
  end

  def script_for(command:, target:)
    return "#{target.enter(separator: "\n")}#{command}" unless rails?(command)

    "#{target.enter_or_stop}\nexec bin/rails #{command.sub(%r{\Abin/}, "").sub(/\Arails/, "").strip}"
  end
end

class Hatchbox::Ssh < Hatchbox::Command
  describe "ps:exec",
    summary: "open an ssh session on one of the app's servers",
    usage: "ps:exec [COMMAND]",
    aliases: ["ssh"],
    flags: [["-s", "--server SERVER", "the server, by name or role"]]

  def call
    usage_error("only one command at a time, quote it as one argument") if positionals.length > 1
    command = positionals.first
    target = Hatchbox::SshTarget.resolve(session: session, filter: options[:server])
    warn("#{target.server_label}, #{target.host}".dim) if target.server && command.nil?
    Hatchbox.run(target.ssh(command: "#{target.enter(separator: "; ")}#{command || "exec ${SHELL:-/bin/bash} -l"}", tty: command.nil?, extra: passthru))
  end
end

class Hatchbox::Deploy < Hatchbox::Command
  describe "deploy",
    summary: "deploy the app's branch, or one commit",
    flags: [
      [nil, "--sha SHA", "deploy this commit instead of the tip of the branch"],
      [nil, "--watch", "stream the build instead of printing what hatchbox queued"],
      [nil, "--no-follow", "print what hatchbox queued, which it does anyway"],
      [nil, "--status", "same as hatchbox status"]
    ]

  def call
    return Hatchbox::Status.call(session: session, args: []) if options[:status] || positionals == ["status"]

    none!
    sha = options[:sha]
    data = client.post("/apps/#{app_id}/deploy", body: Hatchbox.blank?(sha) ? nil : { "sha" => sha }).json || {}
    log_id = data["id"]
    raise Hatchbox::Error, "hatchbox accepted the deploy but returned no log id: #{JSON.dump(data)}" if Hatchbox.blank?(log_id)

    remember_log("deploy", log_id)
    unless options[:watch]
      puts(JSON.pretty_generate(data))
      return 0
    end

    puts("queued deploy to #{label.cyan}, log #{log_id.to_s.cyan}")
    puts
    follow_log(log_id)
  end
end

class Hatchbox::Status < Hatchbox::Command
  describe "status",
    summary: "show the latest deploy and its output",
    hidden: false

  def call
    none!
    puts("#{label.cyan}, app #{app_id}")
    report_deploy
    puts
    log_id = env ? config.get("last_deploy:#{env}") : nil
    return show_log(log_id) unless Hatchbox.blank?(log_id)

    puts(no_log_help.dim)
    0
  end

  private

  def report_deploy
    sha = app.details["last_deploy_sha"].to_s
    if sha.empty?
      puts("no deploy recorded on this app yet")
      return
    end

    at = app.details["last_deploy_at"].to_s
    line = "last deploy #{sha[0, 7].cyan}"
    line = "#{line} at #{at}" unless at.empty?
    puts(line)
    puts("full sha #{sha}".dim)
  end

  def no_log_help
    [
      "no deploy log to stream",
      "hatchbox only serves a log by its id and has no endpoint that lists them, so the",
      "only ids around are the ones written back to",
      "  #{config.path}",
      "deploy from here and the next one is streamable, or pass an id off the dashboard",
      "url to hatchbox releases:output"
    ].join("\n")
  end
end

class Hatchbox::Releases < Hatchbox::Command
  NAMES = {
    "Apps::Deploy" => "deploy",
    "Apps::Restart" => "restart",
    "Apps::EnvVars" => "config",
    "Apps::Maintenance" => "maintenance"
  }.freeze

  describe "releases",
    summary: "display the app's release history",
    flags: [["-n", "--num NUM", "number of releases to display", Integer], [nil, "--page PAGE", "page of older releases", Integer]]

  def call
    none!
    limit = options[:num] || 15
    rows = client.get("/apps/#{app_id}/logs?page=#{options[:page] || 1}&limit=#{limit}").json || []
    if rows.empty?
      puts("nothing on record for #{label}")
      return 0
    end

    puts("#{label.cyan}, app #{app_id}")
    puts
    rows.each { |row| puts(line(row)) }
    puts
    puts("the output of one of these is releases:output ID".dim)
    0
  end

  private

  def line(row)
    id = row["id"].to_s.ljust(9)
    kind = (NAMES[row["name"].to_s] || row["name"].to_s).ljust(11)
    sha = row["commit_sha"].to_s
    sha = sha.empty? ? "".ljust(7) : sha[0, 7]
    "  #{id}#{kind}#{state(row)}#{sha}  #{when_for(row)}  #{row["description"]}"
  end

  def state(row)
    raw = row["state"].to_s
    text = raw.ljust(11)
    return text.green if raw == "completed"
    return text.red if ["failed", "aborted"].include?(raw)

    text.yellow
  end

  def when_for(row)
    stamp = row["created_at"].to_s
    stamp.empty? ? "" : stamp[0, 16].sub("T", " ")
  end
end

class Hatchbox::ReleasesOutput < Hatchbox::Command
  KINDS = {
    "deploy" => "deploy",
    "deploys" => "deploy",
    "restart" => "restart",
    "restarts" => "restart"
  }.freeze

  describe "releases:output",
    summary: "view the output of a release",
    usage: "releases:output RELEASE"

  def call
    wanted = one_positional("log id")
    show_log(wanted =~ /\A[0-9]+\z/ ? wanted : id_for(wanted))
  end

  private

  def id_for(wanted)
    kind = KINDS[wanted]
    raise Hatchbox::Error, "no log type called #{wanted}, releases:output takes a log id, deploy or restart" unless kind

    found = env ? config.get("last_#{kind}:#{env}") : nil
    raise Hatchbox::Error, "no #{kind} has been started from here for #{label}, so there is no log id to fetch. releases lists what hatchbox has" if Hatchbox.blank?(found)

    found
  end
end

class Hatchbox::Domains < Hatchbox::Command
  describe "domains",
    summary: "list the app's domains"

  def call
    none!
    rows = app.domains
    if rows.empty?
      puts("no domains on #{label}, add one with domains:add")
      return 0
    end

    ui.header("domains on #{label}")
    rows.each { |row| puts("  #{row["name"]}") }
    0
  end
end

module Hatchbox::DomainPaths
  private

  def domain_path(name)
    "/apps/#{app_id}/domains/#{URI.encode_www_form_component(name).gsub("+", "%20").gsub("%2A", "*")}"
  end

  def targets
    servers = app.servers.select { |server| server["state"].to_s == "active" }
    fronts = servers.select { |server| (server["roles"] || []).include?("load_balancer") }
    fronts = servers.select { |server| (server["roles"] || []).include?("web") } if fronts.empty?
    fronts.map { |server| server["public_ip"].to_s }.reject { |ip| ip.empty? }
  rescue Hatchbox::Error
    []
  end
end

class Hatchbox::DomainsAdd < Hatchbox::Command
  include Hatchbox::DomainPaths

  describe "domains:add",
    summary: "add a domain to the app",
    usage: "domains:add HOSTNAME"

  def call
    name = one_positional("domain")
    client.post("/apps/#{app_id}/domains", body: { "domain" => { "name" => name } })
    puts("added #{name.cyan} to #{label}")
    ips = targets
    puts("point its dns at #{ui.list(ips)}, caddy gets the certificate once it resolves".dim) if ips.any?
    0
  end
end

class Hatchbox::DomainsRemove < Hatchbox::Command
  include Hatchbox::DomainPaths

  describe "domains:remove",
    summary: "remove a domain from the app",
    usage: "domains:remove HOSTNAME",
    aliases: ["domains:delete"]

  def call
    name = one_positional("domain")
    client.delete(domain_path(name))
    puts("removed #{name.cyan} from #{label}")
    0
  end
end

class Hatchbox::DomainsInfo < Hatchbox::Command
  include Hatchbox::DomainPaths

  describe "domains:info",
    summary: "show one of the app's domains",
    usage: "domains:info HOSTNAME"

  def call
    name = one_positional("domain")
    row = client.get(domain_path(name)).json || {}

    ui.header(row["name"].to_s)
    rows = [["id", row["id"]], ["created", row["created_at"]], ["updated", row["updated_at"]], ["points at", targets.join(", ")]]
    puts(rows.map { |key, value| "  #{key.ljust(14)}#{Hatchbox.blank?(value) ? "-" : value}" }.join("\n"))
    0
  end
end

class Hatchbox::DomainsUpdate < Hatchbox::Command
  include Hatchbox::DomainPaths

  describe "domains:update",
    summary: "rename one of the app's domains",
    usage: "domains:update HOSTNAME NEWHOSTNAME"

  def call
    usage_error("domains:update takes the domain and its new name") unless positionals.length == 2

    old, name = positionals
    client.patch(domain_path(old), body: { "domain" => { "name" => name } })
    puts("#{old} is #{name.cyan} on #{label} now")
    0
  end
end

class Hatchbox::DomainsClear < Hatchbox::Command
  include Hatchbox::DomainPaths

  describe "domains:clear",
    summary: "remove every domain from the app",
    flags: [[nil, "--confirm APP", "the app's name, to skip the prompt"]]

  def call
    none!
    rows = app.domains
    if rows.empty?
      puts("no domains on #{label}")
      return 0
    end

    names = rows.map { |row| row["name"].to_s }
    confirm(expected: app.name, action: "this removes #{names.join(", ")} from #{app.name}")
    names.each { |name| client.delete(domain_path(name)) }
    puts("removed #{ui.list(names)} from #{label}")
    0
  end
end

class Hatchbox::Psql < Hatchbox::Command
  describe "pg:psql",
    summary: "open a psql shell to the database",
    usage: "pg:psql [SQL]",
    aliases: ["psql"],
    flags: [
      ["-c", "--command SQL", "sql command to run"],
      ["-d", "--database NAME", "which postgresql database, when the app has more than one"],
      [nil, "--url", "print the connection uri instead of connecting"],
      [nil, "--direct", "connect straight to the database host instead of through an ssh tunnel"],
      [nil, "--dangerous", "a session that can write, which it cannot by default"]
    ]

  def call
    usage_error("only one statement at a time, quote it as one argument") if positionals.length > 1
    sql = options[:command].to_s.sub(/\A=/, "")
    if positionals.any?
      usage_error("only one statement at a time, quote it as one argument") unless sql.empty?
      sql = positionals.first
    end

    record = choose(options[:database])
    return print_url(record) if options[:url]

    open_psql(record: record, sql: sql)
  end

  private

  def choose(wanted)
    pool = app.databases.select { |record| record["engine"] == "postgresql" }
    pool = pool.select { |record| record["name"] == wanted } unless Hatchbox.blank?(wanted)
    raise Hatchbox::Error, none_message(wanted) if pool.empty?
    raise Hatchbox::Error, "#{label} has more than one postgresql database, so pick one with --database\n\n#{pool.map { |record| "  #{record["name"]}" }.join("\n")}" if pool.length > 1

    pool.first
  end

  def none_message(wanted)
    head = Hatchbox.blank?(wanted) ? "no postgresql database is attached to #{label}" : "no postgresql database called #{wanted} is attached to #{label}"
    return head if app.databases.empty?

    "#{head}\n\nwhat is attached:\n#{attached}"
  end

  def attached
    app.databases.map do |record|
      var = (record["app_attachments"] || []).map { |item| item["env_var"] }.first
      "  #{record["name"]}, #{record["engine"]}, reachable as #{var || "nothing"}"
    end.join("\n")
  end

  def connection_text(record)
    public_uri = record["public_connection_uri"].to_s
    text = Hatchbox.blank?(public_uri) ? record["private_connection_uri"].to_s : public_uri
    raise Hatchbox::Error, "that database has no connection uri, which happens on sqlite" if Hatchbox.blank?(text)

    text
  end

  def print_url(record)
    puts(connection_text(record))
    warn("that host is the database's own machine, so the uri only works from the server".yellow) if Hatchbox.blank?(record["public_connection_uri"])
    0
  end

  def open_psql(record:, sql:)
    database = Hatchbox::Database.new(connection_text(record))
    tunnel = Hatchbox.blank?(record["public_connection_uri"]) && !options[:direct] ? Hatchbox::Tunnel.open(session: session, host: database.host, port: database.port) : nil
    host = tunnel ? "127.0.0.1" : database.host
    port = tunnel ? tunnel.local_port.to_s : database.port
    warn(options[:dangerous] ? "read write session".yellow : "read only session, pass --dangerous to write".dim)
    argv = ["psql", "-h", host, "-p", port, "-U", database.user, "-d", database.name]
    argv.concat(["-c", sql]) unless Hatchbox.blank?(sql)
    argv.concat(passthru)
    begin
      Hatchbox.run(argv, env: environment(database: database, dangerous: options[:dangerous]))
    ensure
      tunnel.close if tunnel
    end
  end

  def environment(database:, dangerous:)
    env = { "PGPASSWORD" => database.password, "PGSSLMODE" => database.sslmode }
    return env if dangerous

    extra = [ENV["PGOPTIONS"], "-c default_transaction_read_only=on"].reject { |part| Hatchbox.blank?(part) }
    env.merge("PGOPTIONS" => extra.join(" "))
  end
end

class Hatchbox::Cli
  class << self
    def call(argv)
      new(argv).call
    end
  end

  def initialize(argv)
    @argv = argv
  end

  def call
    rest = scan
    name = rest.shift
    return help(rest.first) if name.nil? || name == "help"
    return help(name) if @help

    command = Hatchbox::Registry.find(name)
    unknown(name) unless command
    command.call(session: Hatchbox::Session.new(app_flag: @app, remote_flag: @remote), args: rest)
  end

  private

  attr_reader :argv

  def scan
    rest = []
    tokens = argv.dup
    until tokens.empty?
      token = tokens.shift
      if token == "--"
        rest << token
        rest.concat(tokens)
        break
      end

      case token
      when "-a", "--app" then @app = value(token, tokens)
      when /\A--app=(.*)\z/ then @app = Regexp.last_match(1)
      when /\A-a(.+)\z/ then @app = Regexp.last_match(1)
      when "-r", "--remote" then @remote = value(token, tokens)
      when /\A--remote=(.*)\z/ then @remote = Regexp.last_match(1)
      when /\A-r(.+)\z/ then @remote = Regexp.last_match(1)
      when "-h", "--help" then @help = true
      else rest << token
      end
    end
    rest
  end

  def value(flag, tokens)
    found = tokens.shift
    raise Hatchbox::Error, "#{flag} needs a value" if found.nil? || found == "--"

    found
  end

  def help(name)
    command = Hatchbox.blank?(name) ? nil : Hatchbox::Registry.find(name)
    raise Hatchbox::Error, "no command called #{name}, hatchbox help lists them" if command.nil? && !Hatchbox.blank?(name)

    command ? usage(command) : listing
    0
  end

  def listing
    puts("usage: hatchbox COMMAND [-a APP] [-r REMOTE] [options]")
    puts
    rows = Hatchbox::Registry.visible.sort_by { |klass| klass.meta[:name] }
    width = rows.map { |klass| klass.meta[:name].length }.max
    rows.each { |klass| puts("  #{klass.meta[:name].ljust(width)}  #{klass.meta[:summary]}") }
  end

  def usage(command)
    meta = command.meta
    puts("usage: hatchbox #{meta[:usage]}")
    puts
    puts("  #{meta[:summary]}")
    flags = (meta[:app] ? Hatchbox::Command::APP_FLAGS : []) + meta[:flags]
    return if flags.empty?

    puts
    labels = flags.map { |short, long, _description, _type| short ? "#{short}, #{long}" : "    #{long}" }
    width = labels.map { |text| text.length }.max
    flags.each_with_index { |(_short, _long, description, _type), index| puts("  #{labels[index].ljust(width)}  #{description}") }
  end

  def unknown(name)
    raise Hatchbox::Error, "no command called #{name}, hatchbox help lists them"
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    exit(Hatchbox::Cli.call(ARGV).to_i)
  rescue Hatchbox::Error => e
    warn(e.message.red)
    exit(1)
  rescue Errno::EPIPE
    exit(0)
  rescue Interrupt
    exit(130)
  end
end
