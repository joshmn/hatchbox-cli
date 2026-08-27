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
require "time"
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

  def blue
    ansi(34)
  end

  def magenta
    ansi(35)
  end

  def cyan
    ansi(36)
  end

  def dim
    ansi(90)
  end

  def bold
    ansi(1)
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
  FINISHED = ["completed", "failed", "aborted"].freeze
  APP_ROLES = ["web", "worker", "cron", "app"].freeze

  class Error < StandardError; end

  class << self
    attr_writer :force_color

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def color?(io = $stdout)
      return true if @force_color
      return false if ENV["NO_COLOR"]

      io.tty?
    end

    def run(argv, env: {})
      started = system(env, *argv)
      raise Error, "#{argv.first} is required and is not installed." if started.nil?

      exit_code($?)
    end

    def exit_code(status)
      return status.exitstatus if status.exitstatus

      128 + status.termsig.to_i
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

    def ssh_options
      Shellwords.split(ENV["HATCHBOX_SSH_OPTIONS"].to_s)
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
  ANSI = /\e\[[0-9;]*m/.freeze
  PREFIX = " !    "

  class Step
    attr_accessor :status
  end

  class << self
    def header(text)
      puts("=== #{text}".bold)
    end

    def styled_hash(pairs)
      rows = pairs.reject { |_key, value| empty?(value) }
      return if rows.empty?

      width = rows.map { |key, _value| key.length }.max + 2
      rows.each do |key, value|
        lines = Array(value).map { |line| line.to_s }
        puts("#{"#{key}:".ljust(width)}#{lines.first}".rstrip)
        lines.drop(1).each { |line| puts("#{" " * width}#{line}".rstrip) }
      end
    end

    def table(rows, columns)
      titles = columns.map { |title, _getter| title }
      cells = rows.map { |row| columns.map { |_title, getter| getter.call(row).to_s } }
      widths = titles.each_with_index.map do |title, index|
        ([title] + cells.map { |cell| cell[index] }).map { |text| visible(text) }.max
      end
      puts(line(titles, widths))
      puts(widths.map { |width| "-" * width }.join("  "))
      cells.each { |cell| puts(line(cell, widths)) }
    end

    def columns(rows)
      return if rows.empty?

      count = rows.map { |row| row.length }.max
      widths = (0...count).map { |index| rows.map { |row| visible(row[index].to_s) }.max }
      rows.each { |row| puts(line(row.map { |cell| cell.to_s }, widths)) }
    end

    def action(message)
      $stderr.print("#{message}... ")
      $stderr.flush
      step = Step.new
      result = yield(step)
      $stderr.puts(step.status || "done")
      result
    rescue Interrupt, StandardError
      $stderr.puts("!")
      raise
    end

    def error(message)
      emit(message, 31)
    end

    def warning(message)
      emit(message, 33)
    end

    def note(message)
      $stderr.puts(paint(message, 90))
    end

    def confirm(expected:, supplied:, lines:, prompt:)
      return if supplied == expected
      raise Hatchbox::Error, "Confirmation #{supplied} did not match #{expected}. Aborted." unless Hatchbox.blank?(supplied)
      raise Hatchbox::Error, (lines + ["To proceed, re-run this command with --confirm #{expected}"]).join("\n") unless prompt.available?

      warning((["WARNING: Potentially Destructive Action"] + lines + ["To proceed, type \"#{expected}\" or re-run this command with --confirm #{expected}"]).join("\n"))
      $stderr.puts
      answer = prompt.ask(question: "> ", io: $stderr)
      raise Hatchbox::Error, "Confirmation did not match #{expected}. Aborted." unless answer == expected
    end

    def date(value)
      time = parse_time(value)
      return nil unless time

      "#{time.localtime.strftime("%Y/%m/%d %H:%M:%S %z")} (~ #{ago(time)})"
    end

    def short_date(value)
      time = parse_time(value)
      time ? time.localtime.strftime("%Y/%m/%d %H:%M:%S %z") : ""
    end

    def ago(time)
      seconds = [(Time.now - time).to_i, 0].max
      return "#{seconds}s ago" if seconds < 60
      return "#{seconds / 60}m ago" if seconds < 3600
      return "#{seconds / 3600}h ago" if seconds < 86_400

      "#{seconds / 86_400}d ago"
    end

    def duration(from, to)
      start = parse_time(from)
      finish = parse_time(to)
      return nil unless start && finish

      seconds = [(finish - start).to_i, 0].max
      return "#{seconds}s" if seconds < 60

      "#{seconds / 60}m #{seconds % 60}s"
    end

    def parse_time(value)
      return nil if Hatchbox.blank?(value)

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def list(words)
      items = words.map { |word| word.to_s }
      return items.first.to_s if items.length < 2

      "#{items[0..-2].join(", ")} and #{items.last}"
    end

    def plural(count, word)
      "#{count} #{word}#{count == 1 ? "" : "s"}"
    end

    def yes_no(value)
      return "on" if value

      "off"
    end

    def paint(text, code, io: $stderr)
      Hatchbox.color?(io) ? "\e[#{code}m#{text}\e[0m" : text
    end

    def visible(text)
      text.to_s.gsub(ANSI, "").length
    end

    private

    def empty?(value)
      return true if value.nil?
      return value.strip.empty? if value.is_a?(String)
      return value.empty? if value.is_a?(Array)

      false
    end

    def line(texts, widths)
      texts.each_with_index.map { |text, index| pad(text, widths[index]) }.join("  ").rstrip
    end

    def pad(text, width)
      "#{text}#{" " * [width - visible(text), 0].max}"
    end

    def emit(message, code)
      rows = message.to_s.split("\n")
      rows = [""] if rows.empty?
      rows.each { |row| $stderr.puts(paint("#{PREFIX}#{row}".rstrip, code)) }
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
    attr_reader :code, :body, :json, :headers

    def initialize(code:, body:, headers: {})
      @code = code
      @body = body
      @headers = headers
      @json = parse(body)
    end

    def ok?
      code >= 200 && code < 300
    end

    def next_page
      found = headers["link"].to_s.split(",").find { |part| part.include?('rel="next"') }
      found ? found[/<([^>]+)>/, 1] : nil
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
    uri = URI.parse(path.start_with?("http://", "https://") ? path : "#{base}#{path}")
    response = perform(uri: uri, message: build(method: method, uri: uri, body: body))
    Response.new(code: response.code.to_i, body: response.body.to_s, headers: response.each_header.to_h)
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
    raise Hatchbox::Error, "Request to #{uri} failed: #{e.message}"
  end

  def session(uri)
    pool = (Thread.current[:hatchbox_sessions] ||= {})
    key = "#{uri.scheme}://#{uri.host}:#{uri.port}"
    open = pool[key]
    return open if open && open.started?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 15
    http.read_timeout = 90
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
    return "Invalid credentials provided.\nRun hatchbox login, or check HATCHBOX_API_TOKEN." if response.code == 401

    data = response.json
    detail = ""
    if data.is_a?(Hash)
      detail = data["error"].to_s
      detail = Array(data["errors"]).map { |line| sentence(line) }.join("\n") if detail.empty?
    end
    detail.empty? ? "Hatchbox returned HTTP #{response.code}." : sentence(detail)
  end

  private

  attr_reader :http

  def ensure_ok(response)
    return response if response.ok?

    raise Hatchbox::Error, error_message(response)
  end

  def sentence(text)
    words = text.to_s.strip
    words.end_with?(".", "!", "?") ? words : "#{words}."
  end
end

class Hatchbox::Config
  HEADER = [
    "# the apps this repo deploys to, written the way the dashboard url spells them,",
    "# then the environment each one is. pick one with -r, or run hatchbox git:remote to add another."
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
    raise Hatchbox::Error, "#{path} is not writable." unless writable?

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
    raise Hatchbox::Error, "#{path} is not writable." unless writable?

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

  def ask(question:, io: $stderr)
    return nil unless available?

    io.print(question)
    io.flush
    answer = tty.gets
    answer.nil? ? nil : answer.strip
  end

  def secret(question:, io: $stderr)
    return nil unless available?

    io.print(question)
    io.flush
    answer = tty.noecho { |input| input.gets }
    io.puts
    answer.nil? ? nil : answer.strip
  end

  def ask_number(question:, count:, io: $stderr)
    answer = ask(question: question, io: io).to_s
    raise Hatchbox::Error, "#{answer} is not a number." unless answer =~ /\A[0-9]+\z/
    raise Hatchbox::Error, "There is no #{answer} on that list." if answer.to_i < 1 || answer.to_i > count

    answer.to_i
  end

  def yes?(question:, io: $stderr)
    ["y", "yes"].include?(ask(question: question, io: io).to_s.downcase)
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
    return "the HATCHBOX_API_TOKEN environment variable" unless Hatchbox.blank?(ENV["HATCHBOX_API_TOKEN"])
    return "token:#{env} in #{path}" if env && !Hatchbox.blank?(global.get("token:#{env}"))
    return "#{path}" unless Hatchbox.blank?(global.get("token"))

    nil
  end

  def ask
    raise Hatchbox::Error, "No terminal to ask for a token on. Set HATCHBOX_API_TOKEN instead." unless prompt.available?

    $stderr.puts("Enter your Hatchbox API token. New ones are made at https://hatchbox.io/api_tokens")
    token = prompt.secret(question: "Token: ")
    raise Hatchbox::Error, "Nothing entered." if Hatchbox.blank?(token)

    token
  end

  def ensure_token
    token = read
    return token unless Hatchbox.blank?(token)

    token = ask
    save(token)
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
      raise Hatchbox::Error, "Your token can reach no account with an active subscription." if pool.empty?

      raise Hatchbox::Error, (["Pick an account with --account:"] + pool.map { |account| "#{account["name"]} (#{account["id"]})" }).join("\n")
    end

    found = accounts.find do |account|
      [account["id"].to_s, "acct_#{account["id"]}"].include?(wanted.to_s) || account["name"].to_s.casecmp?(wanted.to_s)
    end
    raise Hatchbox::Error, "Couldn't find that account." unless found

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
    raise Hatchbox::Error, "No remote named #{name} in #{config.path}.\n#{remotes_line}" if Hatchbox.blank?(found)

    @env = name
    @slug = found
    @app_id = Hatchbox.slug_id(found)
    raise Hatchbox::Error, "#{found} in #{config.path} does not start with the app's id, the way the dashboard url spells it." if Hatchbox.blank?(@app_id)

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
    raise Hatchbox::Error, "Couldn't find that app." if found.empty?
    if found.length > 1
      rows = found.map { |row| "#{row[:slug]} (#{row[:account]})" }
      raise Hatchbox::Error, (["There is more than one app named #{@wanted}. Use its id with --app:"] + rows).join("\n")
    end

    @slug = found.first[:slug]
    found.first[:id]
  end

  def no_app_message
    "No app specified.\nRun this command from an app folder or specify which app to use with --app APP."
  end

  def multiple_message
    first_env, first_app = config.apps.first
    [
      "Multiple apps in #{config.path}",
      "Usage: --remote #{first_env}",
      "   or: --app #{first_app}",
      "Your .hatchbox names more than one app and has no default line.",
      "Specify the app you want with --app or --remote, or add default = #{first_env} to it.",
      "Remotes in #{config.path}:"
    ].concat(config.apps.map { |env, slug| "#{slug} (#{env})" }).join("\n")
  end

  def remotes_line
    return "It names no apps. Add one with hatchbox git:remote -a APP." if config.envs.empty?

    "Remotes: #{config.envs.uniq.join(", ")}"
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
      raise Hatchbox::Error, "Not logged in.\nRun hatchbox login, or set HATCHBOX_API_TOKEN." if Hatchbox.blank?(found)

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
      raise Hatchbox::Error, "#{label} is on no cluster, so there is no server to reach." if Hatchbox.blank?(cluster_id)

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

  def formation
    @formation ||= Hatchbox::Formation.new(processes: processes, servers: servers)
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

  def attachment_names(record)
    (record["app_attachments"] || []).select { |row| row["app_id"].to_s == id }.map { |row| row["env_var"].to_s }
  end

  def find_database(wanted, engines: nil)
    pool = databases
    pool = pool.select { |record| engines.include?(record["engine"]) } if engines
    return pool if Hatchbox.blank?(wanted)

    text = wanted.to_s
    pool.select do |record|
      record["name"].to_s == text || record["id"].to_s == text || attachment_names(record).map { |name| name.upcase }.include?(text.upcase)
    end
  end

  private

  attr_reader :client
end

class Hatchbox::Formation
  Dyno = Struct.new(:process, :server, :index) do
    def name
      "#{type}.#{index}"
    end

    def type
      process["name"].to_s
    end
  end

  def initialize(processes:, servers:)
    @processes = processes
    @servers = servers
  end

  attr_reader :processes, :servers

  def servers_for(process)
    pinned = process["server_id"]
    return servers.select { |server| server["id"].to_s == pinned.to_s } unless Hatchbox.blank?(pinned)

    roles = Array(process["roles"]).map { |role| role.to_s }
    servers.select { |server| active?(server) && (Array(server["roles"]).map { |role| role.to_s } & roles).any? }.sort_by { |server| server["name"].to_s }
  end

  def dynos(process = nil)
    pool = process ? [process] : processes
    pool.flat_map { |row| servers_for(row).each_with_index.map { |server, index| Dyno.new(row, server, index + 1) } }
  end

  def where(process)
    pinned = process["server_id"]
    return "server #{server_label(pinned)}" unless Hatchbox.blank?(pinned)

    roles = Array(process["roles"]).map { |role| role.to_s }
    roles.empty? ? "nowhere" : "#{roles.length == 1 ? "role" : "roles"} #{roles.join(", ")}"
  end

  def find_process(wanted)
    raise Hatchbox::Error, "Which process?\n#{names_line}" if Hatchbox.blank?(wanted)
    raise Hatchbox::Error, "This app has no processes." if processes.empty?

    text = wanted.to_s.downcase
    exact = processes.find { |row| row["name"].to_s.downcase == text || row["id"].to_s == text }
    return exact if exact

    near = processes.select { |row| row["name"].to_s.downcase.include?(text) }
    return near.first if near.length == 1
    raise Hatchbox::Error, "#{wanted} matches more than one process: #{near.map { |row| row["name"] }.join(", ")}." if near.length > 1

    raise Hatchbox::Error, "No process named #{wanted}.\n#{names_line}"
  end

  def find_dyno(wanted)
    type, _dot, number = wanted.to_s.rpartition(".")
    type, number = wanted.to_s, nil if type.empty? || number !~ /\A[0-9]+\z/
    process = find_process(type)
    pool = dynos(process)
    raise Hatchbox::Error, "#{process["name"]} runs on no active server, #{where(process)}." if pool.empty?
    return pool.first if number.nil?

    found = pool.find { |dyno| dyno.index == number.to_i }
    raise Hatchbox::Error, "There is no #{wanted}. #{process["name"]} runs as #{pool.map { |dyno| dyno.name }.join(", ")}." unless found

    found
  end

  def app_servers
    live = servers.select { |server| active?(server) }
    coded = live.select { |server| (Array(server["roles"]).map { |role| role.to_s } & Hatchbox::APP_ROLES).any? }
    return coded.sort_by { |server| server["name"].to_s } if coded.any?
    return live if live.any?

    servers
  end

  def find_server(wanted)
    raise Hatchbox::Error, "That cluster has no servers." if servers.empty?
    return app_servers.first if Hatchbox.blank?(wanted)

    text = wanted.to_s.downcase
    exact = servers.find { |server| server["name"].to_s.downcase == text || server["id"].to_s == text }
    return exact if exact

    roled = app_servers.select { |server| Array(server["roles"]).map { |role| role.to_s.downcase }.include?(text) }
    roled = servers.select { |server| Array(server["roles"]).map { |role| role.to_s.downcase }.include?(text) } if roled.empty?
    return roled.first if roled.any?

    near = servers.select { |server| server["name"].to_s.downcase.include?(text) }
    return near.first if near.length == 1

    raise Hatchbox::Error, "No server called #{wanted}, and none with that role.\n#{server_listing}"
  end

  def server_listing
    "Servers: #{servers.map { |server| "#{server["name"]} (#{Array(server["roles"]).join(", ")})" }.join(", ")}"
  end

  private

  def active?(server)
    server["state"].to_s == "active"
  end

  def server_label(id)
    found = servers.find { |server| server["id"].to_s == id.to_s }
    found ? found["name"].to_s : id.to_s
  end

  def names_line
    return "This app has no processes." if processes.empty?

    "Processes: #{processes.map { |row| row["name"] }.join(", ")}"
  end
end

class Hatchbox::SshTarget
  attr_reader :host, :user, :port, :server

  def initialize(session:, server: nil)
    @session = session
    @server = server
    @host = setting("ssh_host") || (server ? server["public_ip"].to_s : "")
    @user = setting("ssh_user") || Hatchbox::DEFAULT_SSH_USER
    @port = setting("ssh_port") || (server && !Hatchbox.blank?(server["ssh_port"]) ? server["ssh_port"].to_s : Hatchbox::DEFAULT_SSH_PORT)
    return unless Hatchbox.blank?(host)

    raise Hatchbox::Error, "#{label} has no public IP.\nSet ssh_host:#{session.env || "ENV"} in #{session.config.path}."
  end

  def self.pinned?(session)
    return false if session.env.nil?

    !Hatchbox.blank?(session.config.get("ssh_host:#{session.env}"))
  end

  def address
    "#{user}@#{host}"
  end

  def label
    return server["name"].to_s if server && !Hatchbox.blank?(server["name"])

    Hatchbox.blank?(host) ? "server" : host
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
    raise Hatchbox::Error, "No release directory to run in. Set app_dir:#{session.env || "ENV"} in #{session.config.path}." if Hatchbox.blank?(dir)

    complaint = "#{dir} is not there, so nothing is deployed yet. set app_dir:#{session.env || "ENV"} in .hatchbox if the app lives somewhere else"
    "cd #{Shellwords.escape(dir)} 2>/dev/null || { echo #{Shellwords.escape(complaint)} >&2; exit 1; }"
  end

  def ssh(command: nil, tty: false, extra: [])
    argv = ["ssh", "-p", port.to_s]
    argv.concat(Hatchbox.ssh_options)
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

  attr_reader :session

  def setting(key)
    return nil if session.env.nil?

    session.config.get("#{key}:#{session.env}")
  end
end

class Hatchbox::DatabasePicker
  def initialize(session:)
    @session = session
  end

  def pick
    servers = session.app.servers
    found = servers.find { |server| (server["roles"] || []).include?("postgresql") }
    found = servers.first if found.nil? && servers.length == 1
    raise Hatchbox::Error, "Could not tell which server holds the database. Set ssh_host:#{session.env || "ENV"} in #{session.config.path}." unless found

    found
  end

  private

  attr_reader :session
end

class Hatchbox::Database
  def initialize(text)
    @uri = URI.parse(text)
  rescue URI::InvalidURIError
    raise Hatchbox::Error, "Could not read the connection URI Hatchbox returned."
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
    server = Hatchbox::SshTarget.pinned?(session) ? nil : Hatchbox::DatabasePicker.new(session: session).pick
    @target = Hatchbox::SshTarget.new(session: session, server: server)
    @local_port = free_port
    @dir = Dir.mktmpdir("hbx", "/tmp")
    Hatchbox::Ui.note("Tunnelling to #{host}:#{port} through #{target.address}")
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
    argv = ["ssh", "-f", "-N", "-M", "-S", control, "-o", "ExitOnForwardFailure=yes", "-o", "ConnectTimeout=10", "-p", target.port.to_s]
    argv.concat(Hatchbox.ssh_options)
    argv.concat(["-L", "127.0.0.1:#{local_port}:#{host}:#{port}", target.address])
  end

  def failure_message
    "Could not open an SSH tunnel. Hatchbox puts your key on the deploy user, so\n" \
      "check that ssh #{target.address} works, or set ssh_user:#{session.env || "ENV"} in #{session.config.path}."
  end

  def free_port
    socket = TCPServer.new("127.0.0.1", 0)
    picked = socket.addr[1]
    socket.close
    picked
  end
end

class Hatchbox::Operation
  Result = Struct.new(:log, :state, :gone) do
    def ok?
      gone || state == "completed"
    end
  end

  def initialize(client:, app: nil)
    @client = client
    @app = app
    @seen = {}
    @headers = {}
  end

  def fetch(log_id)
    client.get("/logs/#{log_id}").json || {}
  end

  def wait(log_id, gone_ok: false)
    poll(log_id, gone_ok: gone_ok) { |_log| nil }
  end

  def stream(log_id, gone_ok: false)
    poll(log_id, gone_ok: gone_ok) do |log|
      emit(key: "parent", text: log["body"].to_s)
      emit_children(log)
    end
  end

  def print_log(log)
    body = log["body"].to_s
    print(body)
    puts if !body.empty? && !body.end_with?("\n")
    (log["child_logs"] || []).each do |child|
      text = child["body"].to_s
      next if text.empty?

      puts
      puts("Output from #{server_label(child)}".cyan)
      print(text)
      puts unless text.end_with?("\n")
    end
    $stdout.flush
  end

  def report_failure(result)
    log = result.log || {}
    children = (log["child_logs"] || []).reject { |child| child["body"].to_s.empty? }
    pool = children.select { |child| child["state"].to_s != "completed" }
    pool = children if pool.empty?
    if pool.empty?
      text = log["body"].to_s
      $stderr.print(text)
      $stderr.puts unless text.empty? || text.end_with?("\n")
    else
      pool.each do |child|
        $stderr.puts("Output from #{server_label(child)}")
        $stderr.print(child["body"].to_s)
        $stderr.puts unless child["body"].to_s.end_with?("\n")
      end
    end
    Hatchbox::Ui.error("#{log["name"]} #{result.state}. The full log is hatchbox releases:output #{log["id"]}")
  end

  private

  attr_reader :client, :app, :seen, :headers

  def poll(log_id, gone_ok:)
    waited = 0
    loop do
      response = client.raw("GET", "/logs/#{log_id}")
      return Result.new(nil, "completed", true) if response.code == 404 && gone_ok
      raise Hatchbox::Error, client.error_message(response) unless response.ok?

      log = response.json || {}
      yield(log)
      state = log["state"].to_s
      return Result.new(log, state, false) if Hatchbox::FINISHED.include?(state)
      raise Hatchbox::Error, "Gave up watching after #{Hatchbox::MAX_WAIT_SECONDS / 60} minutes, still #{state}.\nPick it back up with hatchbox releases:output #{log_id}" if waited >= Hatchbox::MAX_WAIT_SECONDS

      sleep(Hatchbox::POLL_SECONDS)
      waited += Hatchbox::POLL_SECONDS
    end
  rescue Interrupt
    $stderr.puts
    Hatchbox::Ui.warning("Stopped watching. It keeps running on Hatchbox; pick it back up with hatchbox releases:output #{log_id}")
    raise
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

  def emit_children(log)
    (log["child_logs"] || []).each do |child|
      text = child["body"].to_s
      id = child["id"]
      if !text.empty? && !headers[id]
        puts
        puts("Output from #{server_label(child)}".cyan)
        headers[id] = true
      end
      emit(key: "child-#{id}", text: text)
    end
  end

  def server_label(child)
    return "server #{child["loggable_id"]}" unless app

    app.server_name(child["loggable_id"])
  end
end

class Hatchbox::Journal
  FIELDS = "MESSAGE,_SYSTEMD_UNIT,_SYSTEMD_USER_UNIT,UNIT,USER_UNIT,SYSLOG_IDENTIFIER"
  LIVE = '{"__hbx":"live"}'

  def initialize(units: [], identifiers: [], lines: 100, follow: false, since: nil, units_only: false)
    @units = units
    @identifiers = identifiers
    @lines = lines
    @follow = follow
    @since = since
    @units_only = units_only
  end

  def script
    [
      "set -u",
      "[ -n \"${XDG_RUNTIME_DIR:-}\" ] || export XDG_RUNTIME_DIR=/run/user/$(id -u)",
      "args=''",
      "found=0",
      "system=0",
      *units.map { |unit| check(unit) },
      *identifiers.map { |name| "args=\"$args -t #{quote(name)}\"; found=1" },
      "if [ \"$found\" = 0 ]; then exit 3; fi",
      "if [ \"$system\" = 1 ] && [ \"$(id -u)\" != 0 ] && ! id -nG | tr ' ' '\\n' | grep -qxE 'adm|systemd-journal'; then echo #{quote(JSON.dump("__hbx" => "blind"))}; fi",
      *reading
    ].join("\n")
  end

  private

  attr_reader :units, :identifiers, :lines, :follow, :since, :units_only

  def check(unit)
    name = quote(unit)
    [
      "if systemctl --user cat #{name} >/dev/null 2>&1; then args=\"$args --user-unit=#{unit}\"; found=1; echo #{marker("unit", unit, "user")}",
      "elif systemctl cat #{name} >/dev/null 2>&1; then args=\"$args -u #{unit}\"; found=1; system=1; echo #{marker("unit", unit, "system")}",
      "else echo #{marker("missing", unit, nil)}; fi"
    ].join("\n")
  end

  def marker(kind, unit, scope)
    data = { "__hbx" => kind, "unit" => unit }
    data["scope"] = scope if scope
    quote(JSON.dump(data))
  end

  def reading
    return ["exit 0"] if units_only

    common = "journalctl -q --all -o json --output-fields=#{FIELDS} $args"
    window = "-n #{lines.to_i}#{Hatchbox.blank?(since) ? "" : " --since #{quote(since)}"}"
    return ["exec #{common} #{window} --no-pager"] unless follow

    [
      "out=$(#{common} #{window} --no-pager)",
      "[ -n \"$out\" ] && printf '%s\\n' \"$out\"",
      "echo #{quote(LIVE)}",
      "cursor=$(printf '%s\\n' \"$out\" | tail -n 1 | sed -n 's/^{ *\"__CURSOR\" *: *\"\\([^\"]*\\)\".*/\\1/p')",
      "if [ -n \"$cursor\" ]; then exec #{common} -f --after-cursor=\"$cursor\"; fi",
      "exec #{common} -f -n 0"
    ]
  end

  def quote(text)
    Shellwords.escape(text)
  end
end

class Hatchbox::LogReader
  PALETTE = [36, 32, 33, 35, 34, 31].freeze

  Plan = Struct.new(:target, :units, :identifiers, keyword_init: true)
  Entry = Struct.new(:time, :source, :dyno, :message, :color, :order)

  def initialize(plans:, lines:, follow:, since:, source:, units_only:, colors:)
    @plans = plans
    @lines = lines
    @follow = follow
    @since = since
    @source = source
    @units_only = units_only
    @colors = colors
    @queue = Queue.new
    @children = []
    @seen = Hash.new { |hash, key| hash[key] = {} }
    @missing = []
    @found = Hash.new { |hash, key| hash[key] = [] }
    @blind = []
    @order = 0
  end

  def run
    start
    backlog = collect
    report_units if units_only
    return units_only_status if units_only

    print_entries(backlog.sort_by { |entry| [entry.time, entry.order] }.last(lines))
    stream if follow
    finish
  ensure
    stop
  end

  private

  attr_reader :plans, :lines, :follow, :since, :source, :units_only, :colors, :queue, :children, :seen

  def start
    plans.each_with_index do |plan, index|
      journal = Hatchbox::Journal.new(
        units: plan.units.keys,
        identifiers: plan.identifiers.keys,
        lines: Hatchbox.blank?(source) ? lines : [lines * 50, 10_000].min,
        follow: follow,
        since: since,
        units_only: units_only
      )
      argv = plan.target.ssh(command: "bash -c #{Shellwords.escape(journal.script)}")
      stdin, stdout, stderr, waiter = Open3.popen3(*argv)
      stdin.close
      children << waiter
      Thread.new { stdout.each_line { |line| queue << [:line, index, line] }; queue << [:eof, index, nil] }
      Thread.new { stderr.each_line { |line| queue << [:err, index, line] } }
      Thread.new { queue << [:exit, index, Hatchbox.exit_code(waiter.value)] }
    end
  rescue Errno::ENOENT
    raise Hatchbox::Error, "ssh is required and is not installed."
  end

  def collect
    @live = {}
    @closed = {}
    @exits = {}
    entries = []
    until plans.each_index.all? { |index| settled?(index) }
      kind, index, payload = queue.pop
      handle(kind: kind, index: index, payload: payload) { |entry| entries << entry }
    end
    entries
  end

  def stream
    until plans.each_index.all? { |index| @exits.key?(index) && @closed[index] }
      kind, index, payload = queue.pop
      handle(kind: kind, index: index, payload: payload) { |entry| print_entries([entry]) }
    end
  end

  def settled?(index)
    return true if @exits.key?(index) && @closed[index]
    return false unless follow

    @live[index] || (@exits.key?(index) && @closed[index])
  end

  def handle(kind:, index:, payload:)
    case kind
    when :err
      $stderr.print(plans.length > 1 ? "#{plans[index].target.label}: #{payload}" : payload)
    when :eof
      @closed[index] = true
    when :exit
      @exits[index] = payload
    when :line
      entry = parse(index: index, text: payload)
      yield(entry) if entry && wanted?(entry)
    end
  end

  def parse(index:, text:)
    return nil if text.strip.empty?

    data = JSON.parse(text)
    return marker(index: index, data: data) if data.key?("__hbx")

    cursor = data["__CURSOR"].to_s
    return nil if !cursor.empty? && seen[index].key?(cursor)

    seen[index][cursor] = true unless cursor.empty?
    build(plan: plans[index], data: data)
  rescue JSON::ParserError
    $stderr.print(text)
    nil
  end

  def marker(index:, data:)
    case data["__hbx"]
    when "live" then @live[index] = true
    when "missing" then @missing << [plans[index].target.label, data["unit"]]
    when "unit" then @found[index] << "#{data["unit"]} (#{data["scope"]})"
    when "blind" then @blind << plans[index].target.label
    end
    nil
  end

  def build(plan:, data:)
    unit, kind = locate(plan: plan, data: data)
    dyno = unit ? plan.units[unit] : nil
    ident = data["SYSLOG_IDENTIFIER"].to_s
    dyno ||= plan.identifiers[ident]
    dyno ||= { name: (data["_SYSTEMD_USER_UNIT"] || data["_SYSTEMD_UNIT"] || ident).to_s.sub(/\.service\z/, ""), color: 37 }
    @order += 1
    Entry.new(time_of(data), kind || "app", dyno[:name], message_of(data["MESSAGE"]), dyno[:color], @order)
  end

  def locate(plan:, data:)
    found = [data["_SYSTEMD_USER_UNIT"], data["_SYSTEMD_UNIT"]].find { |unit| plan.units.key?(unit) }
    return [found, "app"] if found

    found = [data["USER_UNIT"], data["UNIT"]].find { |unit| plan.units.key?(unit) }
    return [found, "systemd"] if found

    [nil, nil]
  end

  def time_of(data)
    micros = data["__REALTIME_TIMESTAMP"].to_i
    Time.at(micros / 1_000_000, micros % 1_000_000, :usec).utc
  end

  def message_of(value)
    text = value.is_a?(Array) ? value.pack("C*").force_encoding(Encoding::UTF_8).scrub : value.to_s
    text.chomp
  end

  def wanted?(entry)
    Hatchbox.blank?(source) || entry.source == source
  end

  def print_entries(entries)
    entries.each do |entry|
      label = "#{entry.source}[#{entry.dyno}]:"
      label = "\e[#{entry.color}m#{label}\e[0m" if colors
      $stdout.puts("#{entry.time.strftime("%Y-%m-%dT%H:%M:%S.%6N+00:00")} #{label} #{entry.message}")
    end
    $stdout.flush
  end

  def report_units
    plans.each_with_index do |plan, index|
      Hatchbox::Ui.header("#{plan.target.label} (#{plan.target.host})")
      @found[index].each { |line| puts(line) }
      @missing.select { |label, _unit| label == plan.target.label }.each { |_label, unit| puts("#{unit} (not on this server)") }
      plan.identifiers.each_key { |name| puts("#{name} (identifier)") }
      puts
    end
  end

  def units_only_status
    @exits.values.all? { |code| code.zero? } ? 0 : 1
  end

  def finish
    @missing.each { |label, unit| Hatchbox::Ui.warning("There is no #{unit} on #{label}.") }
    @blind.uniq.each { |label| Hatchbox::Ui.warning("The deploy user on #{label} cannot read the system journal. Add it to the systemd-journal group to see those lines.") }
    failed = @exits.select { |_index, code| code != 0 && code != 130 && code != 143 }
    return 0 if failed.empty?
    return 0 if failed.length < plans.length

    raise Hatchbox::Error, "No systemd unit to read. Try hatchbox logs --units to see what it looked for." if failed.values.uniq == [3]

    failed.values.first
  end

  def stop
    children.each do |waiter|
      next unless waiter.alive?

      Process.kill("TERM", waiter.pid)
    rescue SystemCallError
      nil
    end
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

  WAIT_FLAG = [nil, "--no-wait", "return once Hatchbox has queued it, without waiting for it to finish"].freeze

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
        raise Hatchbox::Error, "Unexpected argument: #{e.args.join(" ")}\nSee more help with --help" unless meta[:lenient]

        @positionals.concat(e.args)
      end
    end
  rescue OptionParser::MissingArgument => e
    raise Hatchbox::Error, "Flag #{e.args.join(" ")} expects a value."
  rescue OptionParser::ParseError => e
    raise Hatchbox::Error, "#{e.message[0].upcase}#{e.message[1..-1]}."
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
    raise Hatchbox::Error, "Usage: hatchbox #{meta[:usage]}\n#{message}"
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

  def operation
    @operation ||= Hatchbox::Operation.new(client: client, app: meta[:app] ? app : nil)
  end

  def queued(message, log_id, gone_ok: false)
    raise Hatchbox::Error, "Hatchbox accepted it but returned no log id." if Hatchbox.blank?(log_id)

    if options[:no_wait]
      ui.action(message) { |step| step.status = "done, queued as #{log_id}" }
      return 0
    end

    result = nil
    ui.action(message) do |step|
      result = operation.wait(log_id, gone_ok: gone_ok)
      step.status = result.ok? ? "done" : ui.paint(result.state.to_s, 31)
    end
    return 0 if result.ok?

    operation.report_failure(result)
    1
  end

  def one_positional(what)
    usage_error("Must specify #{what}.") if positionals.empty?
    usage_error("Only one #{what} at a time, got #{positionals.join(" ")}.") if positionals.length > 1

    positionals.first
  end

  def confirm(expected:, lines:)
    ui.confirm(expected: expected, supplied: options[:confirm], lines: lines, prompt: prompt)
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
    usage_error("Unexpected argument: #{positionals.join(" ")}") if positionals.any?
  end
end

class Hatchbox::AuthLogin < Hatchbox::Command
  describe "auth:login",
    summary: "log in with a Hatchbox API token",
    aliases: ["login"],
    app: false,
    flags: [[nil, "--token TOKEN", "use this token instead of asking for one, which puts it in your shell history"]]

  def call
    none!
    store = Hatchbox::TokenStore.new(prompt: prompt)
    token = Hatchbox.blank?(options[:token]) ? store.ask : options[:token]
    accounts = []
    ui.action("Logging in") do
      probe = Hatchbox::Client.new(token: token)
      response = probe.raw("GET", "/accounts")
      raise Hatchbox::Error, probe.error_message(response) unless response.ok?

      accounts = response.json || []
    end
    store.save(token)
    puts("Logged in with access to #{ui.list(accounts.map { |account| account["name"] })}")
    ui.warning("HATCHBOX_API_TOKEN is set in your environment, and it wins over #{store.path} until you unset it.") unless Hatchbox.blank?(ENV["HATCHBOX_API_TOKEN"])
    0
  end
end

class Hatchbox::AuthLogout < Hatchbox::Command
  describe "auth:logout",
    summary: "clear the saved API token",
    aliases: ["logout"],
    app: false

  def call
    none!
    store = Hatchbox::TokenStore.new(prompt: prompt)
    ui.action("Logging out") { store.forget }
    ui.warning("HATCHBOX_API_TOKEN is still set in your environment, so commands will keep working until you unset it.") unless Hatchbox.blank?(ENV["HATCHBOX_API_TOKEN"])
    0
  end
end

class Hatchbox::AuthToken < Hatchbox::Command
  describe "auth:token",
    summary: "display the API token in use",
    app: false

  def call
    none!
    puts(session.token)
    0
  end
end

class Hatchbox::AuthWhoami < Hatchbox::Command
  describe "auth:whoami",
    summary: "display the accounts the API token can reach",
    aliases: ["whoami"],
    app: false

  def call
    none!
    accounts = client.get("/accounts").json || []
    accounts.each { |account| puts("#{account["name"]} (#{account["id"]})") }
    ui.note("token from #{Hatchbox::TokenStore.new.source(env: session.remote_flag)}")
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
      ui.header("#{account["name"]} Apps")
      mine.each { |row| puts("#{row[:name]} (#{clusters[row[:cluster_id]] || "cluster #{row[:cluster_id]}"})") }
      shown += 1
    end
    puts("You have no apps.") if shown.zero?
    catalog.skipped.each { |name, message| ui.warning("Skipped #{name}: #{message}") }
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
    ["Pre Build Script", "pre_build_script"],
    ["Build Script", "build_script"],
    ["Post Build Script", "post_build_script"],
    ["Post Deploy Script", "post_deploy_script"],
    ["Failed Deploy Script", "failed_deploy_script"],
    ["Caddyfile", "caddyfile"],
    ["DNS Provider", "dns_provider"],
    ["DNS API User", "dns_api_user"]
  ].freeze

  describe "apps:info",
    summary: "show detailed app information",
    usage: "apps:info [APP]",
    aliases: ["info"],
    flags: [["-x", "--extended", "show the deploy scripts, the Caddyfile and the DNS settings too"], ["-s", "--shell", "output more shell friendly key/value pairs"]]

  def call
    usage_error("Only one app at a time.") if positionals.length > 1
    data = gather
    return shell(data) if options[:shell]

    ui.header(data["name"])
    ui.styled_hash(pairs(data))
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
      "databases" => found[:databases].map { |record| record.slice("id", "name", "engine", "database_cluster_id").merge("as" => app.attachment_names(record)) },
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
      ["Databases", data["databases"].map { |record| "#{record["name"]} (#{record["engine"]})#{record["as"].empty? ? "" : " as #{record["as"].join(", ")}"}" }],
      ["Auto Deploy", ui.yes_no(data["auto_deploy"])],
      ["Branch", data["branch"]],
      ["Cluster", "#{cluster["name"]} (#{[cluster["provider"], cluster["region"]].compact.join(" ")})"],
      ["Domains", data["domains"]],
      ["Git Provider", data["git_provider"]],
      ["Health Check", data["health_check_uri"]],
      ["Id", data["id"].to_s],
      ["Last Deploy", last_deploy(data)],
      ["Maintenance", ui.yes_no(data["maintenance"])],
      ["Processes", data["processes"].map { |row| "#{row["name"]} (#{app.formation.where(row)})#{row["active"] ? "" : ", disabled"}" }],
      ["Repo", data["repo_path"]],
      ["Servers", data["servers"].map { |server| "#{server["name"]} (#{Array(server["roles"]).join(", ")})" }],
      ["Team", data["team"]],
      ["Web URL", data["web_url"]]
    ]
    rows.concat(EXTENDED.map { |title, key| [title, data[key].to_s.split("\n")] }) if options[:extended]
    rows.sort_by { |key, _value| key }
  end

  def last_deploy(data)
    sha = data["last_deploy_sha"].to_s
    return nil if sha.empty?

    [sha[0, 7], ui.date(data["last_deploy_at"])].compact.join(" ")
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
    usage_error("Must specify NAME.") if Hatchbox.blank?(name)
    usage_error("Only one name at a time.") if positionals.length > 1
    raise Hatchbox::Error, "#{name} is not a name Hatchbox takes. Use letters, numbers, hyphens and underscores." unless name =~ NAME

    catalog = session.catalog
    account = catalog.find_account(options[:account])
    cluster = pick_cluster(catalog.clusters_for(account))
    body = { "cluster_id" => cluster["id"], "name" => name }
    body["branch"] = options[:branch] unless Hatchbox.blank?(options[:branch])
    body["repo_path"] = options[:repo] unless Hatchbox.blank?(options[:repo])
    body["connected_account_id"] = pick_provider(catalog.git_providers_for(account))["id"] unless Hatchbox.blank?(options[:git_provider])
    created = nil
    ui.action("Creating #{name} on #{cluster["name"]}") { created = client.post("/apps", body: { "app" => body }).json || {} }
    slug = "#{created["id"]}-#{created["name"] || name}"
    options[:no_remote] ? puts(slug) : remember(slug)
    0
  end

  private

  def pick_cluster(clusters)
    wanted = options[:cluster]
    if Hatchbox.blank?(wanted)
      return clusters.first if clusters.length == 1
      raise Hatchbox::Error, "That account has no clusters. Make one on the dashboard first." if clusters.empty?

      raise Hatchbox::Error, (["Pick a cluster with --cluster:"] + clusters.map { |row| "#{row["name"]} (#{row["id"]})" }).join("\n")
    end

    found = clusters.find { |row| row["id"].to_s == wanted.to_s || row["name"].to_s.casecmp?(wanted.to_s) }
    raise Hatchbox::Error, (["No cluster called #{wanted}. Clusters:"] + clusters.map { |row| "#{row["name"]} (#{row["id"]})" }).join("\n") unless found

    found
  end

  def pick_provider(providers)
    wanted = options[:git_provider].to_s
    found = providers.select { |row| row["id"].to_s == wanted || row["name"].to_s.casecmp?(wanted) || "#{row["provider"]}:#{row["name"]}".casecmp?(wanted) }
    return found.first if found.length == 1

    listing = providers.map { |row| "#{row["provider"]}:#{row["name"]} (#{row["id"]})" }
    raise Hatchbox::Error, (["More than one git provider is called #{wanted}. Use provider:name or the id:"] + listing).join("\n") if found.length > 1

    raise Hatchbox::Error, (["No git provider called #{wanted}. Providers:"] + listing).join("\n")
  end

  def remember(slug)
    target = Hatchbox::Config.find || (Hatchbox::Config.repo_root && Hatchbox::Config.target)
    return puts(slug) unless target

    file = Hatchbox::Config.new(target)
    remote = Hatchbox.blank?(session.remote_flag) ? "production" : session.remote_flag
    existing = file.app_for(remote)
    unless Hatchbox.blank?(existing)
      ui.warning("#{file.path} already has #{remote} as #{existing}, so it was left alone. Add this one with hatchbox git:remote -a #{slug} -r NAME")
      return
    end

    file.set_app(env: remote, app: slug)
    puts("set .hatchbox remote #{remote} to #{slug}")
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
    flags: [[nil, "--confirm APP", "the app's name, to skip the prompt"], WAIT_FLAG]

  def call
    usage_error("Only one app at a time.") if positionals.length > 1
    name = app.name
    confirm(expected: name, lines: ["This command will destroy #{name}, its folder and services on every server.", "Its databases are detached, not deleted."])
    log_id = (client.delete("/apps/#{app_id}", body: { "name" => name }).json || {})["id"]
    code = queued("Destroying #{name} (databases are detached, not deleted)", log_id, gone_ok: true)
    return code unless code.zero?

    gone = config.remove_app_id(app_id)
    ui.note("removed #{ui.list(gone)} from #{config.path}") if gone.any?
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
    flags: [[nil, "--confirm APP", "the app's current name, to skip the prompt"], WAIT_FLAG]

  def call
    new_name = one_positional("NEWNAME")
    raise Hatchbox::Error, "#{new_name} is not a name Hatchbox takes. Use letters, numbers, hyphens and underscores." unless new_name =~ Hatchbox::AppsCreate::NAME

    old = app.name
    raise Hatchbox::Error, "New name must be different from the current name." if new_name == old

    confirm(expected: old, lines: ["Renaming #{old} stops its processes and moves its folder, so it is down until this finishes."])
    log_id = (client.post("/apps/#{app_id}/rename", body: { "app" => { "name" => new_name } }).json || {})["id"]
    code = queued("Renaming #{old} to #{new_name}", log_id)
    return code unless code.zero?

    moved = config.rename_app_id(app_id: app_id, slug: "#{app_id}-#{new_name}")
    moved.each { |remote| puts(".hatchbox remote #{remote} updated") }
    0
  end
end

class Hatchbox::AppsOpen < Hatchbox::Command
  describe "apps:open",
    summary: "open the app in a web browser",
    usage: "apps:open [PATH]",
    aliases: ["open"]

  def call
    usage_error("Only one path at a time.") if positionals.length > 1
    base = app.web_url
    raise Hatchbox::Error, "#{label} has no domains, so there is nothing to open. Add one with hatchbox domains:add." unless base

    url = "#{base.chomp("/")}/#{positionals.first.to_s.sub(%r{\A/}, "")}"
    opener = RbConfig::CONFIG["host_os"] =~ /darwin/ ? "open" : "xdg-open"
    ui.action("Opening #{url}") { Hatchbox.run([opener, url]) }
    0
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
    summary: "change an app's branch, repo, deploy scripts or Caddy settings",
    flags: [
      ["-b", "--branch BRANCH", "branch to deploy"],
      [nil, "--repo REPO", "repository to deploy, e.g. myuser/my-app"],
      [nil, "--git-provider PROVIDER", "connected git account to deploy from, by name or id"],
      [nil, "--pre-build-script SCRIPT", "script run before the build, or @FILE to read it from a file"],
      [nil, "--build-script SCRIPT", "build script, or @FILE"],
      [nil, "--post-build-script SCRIPT", "script run after the build, or @FILE"],
      [nil, "--post-deploy-script SCRIPT", "script run after the deploy, or @FILE"],
      [nil, "--failed-deploy-script SCRIPT", "script run once when a deploy fails, or @FILE"],
      [nil, "--health-check PATH", "relative path for Caddy to health check, e.g. /up"],
      [nil, "--caddyfile FILE", "Caddyfile to apply, or - to read it from stdin"],
      [nil, "--dns-provider PROVIDER", "DNS provider for certificates"],
      [nil, "--dns-api-user USER", "DNS API user"],
      [nil, "--dns-access-token TOKEN", "DNS access token, which Hatchbox never returns"]
    ]

  def call
    none!
    body = {}
    FIELDS.each { |flag, field| body[field] = expand(options[flag]) if options.key?(flag) }
    body["caddyfile"] = caddyfile(options[:caddyfile]) if options.key?(:caddyfile)
    body["connected_account_id"] = provider_id(options[:git_provider]) if options.key?(:git_provider)
    usage_error("Nothing to change. See hatchbox help apps:update.") if body.empty?
    raise Hatchbox::Error, "--health-check must be a relative path like /up." if body.key?("health_check_uri") && !body["health_check_uri"].to_s.start_with?("/")

    ui.action("Updating #{label}") { client.patch("/apps/#{app_id}", body: { "app" => body }) }
    ui.styled_hash(body.map { |key, value| [key, summary(key, value)] })
    ui.note("Caddy is being reapplied on the servers") if body.key?("caddyfile") || body.key?("health_check_uri")
    0
  end

  private

  def expand(value)
    text = value.to_s
    return text unless text.start_with?("@")

    File.read(text[1..-1])
  rescue Errno::ENOENT
    raise Hatchbox::Error, "No file at #{text[1..-1]}."
  end

  def caddyfile(path)
    return $stdin.read if path == "-"

    File.read(path)
  rescue Errno::ENOENT
    raise Hatchbox::Error, "No file at #{path}."
  end

  def provider_id(wanted)
    account = session.catalog.account_for(app_id)
    raise Hatchbox::Error, "Could not tell which account #{label} is on." unless account

    providers = session.catalog.git_providers_for(account)
    found = providers.select { |row| row["id"].to_s == wanted.to_s || row["name"].to_s.casecmp?(wanted.to_s) || "#{row["provider"]}:#{row["name"]}".casecmp?(wanted.to_s) }
    return found.first["id"] if found.length == 1

    raise Hatchbox::Error, (["Could not pick a git provider from #{wanted}. Providers:"] + providers.map { |row| "#{row["provider"]}:#{row["name"]} (#{row["id"]})" }).join("\n")
  end

  def summary(key, value)
    return "(set)" if key == "dns_access_token"

    lines = value.to_s.split("\n")
    lines.length > 1 ? "#{lines.length} lines" : value.to_s
  end
end

class Hatchbox::Remotes < Hatchbox::Command
  describe "remotes",
    summary: "list the apps named in .hatchbox",
    aliases: ["envs", "git:remotes"],
    app: false

  def call
    none!
    raise Hatchbox::Error, "No .hatchbox here or above #{Dir.pwd}. Add one with hatchbox git:remote." unless config.exists?

    ui.header(config.path)
    current = begin
      session.target.env
    rescue Hatchbox::Error
      nil
    end
    width = config.envs.map { |name| name.length }.max.to_i
    config.apps.each do |name, slug|
      puts("#{name.ljust(width)}  #{slug}#{name == current ? "  (default)".green : ""}")
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
    usage_error("Only one filter at a time.") if positionals.length > 1
    Hatchbox::TokenStore.new(prompt: prompt).ensure_token
    @file = Hatchbox::Config.new(Hatchbox::Config.target)
    slug = Hatchbox.blank?(session.app_flag) ? choose_app(positionals.first) : resolve(session.app_flag)
    remote = options[:as] || session.remote_flag
    remote = ask_remote(guess_remote(slug)) if Hatchbox.blank?(remote)
    validate(remote)
    return 1 unless replace?(remote: remote, slug: slug)

    file.set_app(env: remote, app: slug)
    puts("set .hatchbox remote #{remote} to #{slug}")
    choose_default
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
    raise Hatchbox::Error, Hatchbox.blank?(filter) ? "The token can see no apps at all." : "No app matches #{filter}." if rows.empty?

    matched = rows.select { |row| repos.include?(normalize(row[:record]["repo_path"])) }
    if matched.length == 1
      $stderr.puts("Found #{matched.first[:slug]}, which deploys #{matched.first[:record]["repo_path"]}")
      return matched.first[:slug]
    end
    unless prompt.available?
      raise Hatchbox::Error, (["More than one app deploys this repo. Pick one with -a:"] + matched.map { |row| row[:slug] }).join("\n") if matched.any?

      raise Hatchbox::Error, "git:remote needs a terminal to pick from, or pass -a APP and -r REMOTE."
    end

    pool = matched.any? ? matched : rows
    $stderr.puts
    $stderr.puts("Apps that deploy #{ui.list(matched.map { |row| row[:record]["repo_path"] }.uniq)}:") if matched.any?
    pool.each_with_index { |row, index| $stderr.puts(format("%3d  %-34s %s", index + 1, row[:slug], row[:account])) }
    $stderr.puts
    pool[prompt.ask_number(question: "Which app? ", count: pool.length) - 1][:slug]
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

  def guess_remote(slug)
    found = Hatchbox.slug_name(slug)[/[-_](production|prod|staging|stage|qa|dev|development|test|demo|preview)\z/i, 1].to_s.downcase
    { "" => "production", "prod" => "production", "stage" => "staging", "dev" => "development" }.fetch(found, found)
  end

  def ask_remote(suggested)
    return suggested unless prompt.available?

    answer = prompt.ask(question: "Remote name [#{suggested}]: ")
    Hatchbox.blank?(answer) ? suggested : answer
  end

  def validate(remote)
    return unless remote =~ /[:=\s]/

    raise Hatchbox::Error, "A remote name cannot hold a colon, an equals sign or a space."
  end

  def replace?(remote:, slug:)
    existing = file.exists? ? file.app_for(remote) : nil
    return true if Hatchbox.blank?(existing) || existing == slug

    ui.warning("#{remote} is already #{existing} in #{file.path}.")
    return true unless prompt.available? && Hatchbox.blank?(ENV["HATCHBOX_ASSUME_YES"])
    return true if prompt.yes?(question: "Point it at #{slug} instead? [y/N] ")

    $stderr.puts("Left alone.")
    false
  end

  def choose_default
    remotes = file.envs.uniq
    return if remotes.length < 2 || !Hatchbox.blank?(file.get("default"))

    ui.warning("#{file.path} has more than one remote now, so every command wants -r unless one is the default.")
    return unless prompt.available?

    answer = prompt.ask(question: "Default remote (blank to always pass -r): ")
    return if Hatchbox.blank?(answer)
    return ui.warning("No remote called #{answer}, so the default is unset.") unless remotes.include?(answer)

    file.set(key: "default", value: answer)
    puts("default remote is #{answer}")
  end
end

class Hatchbox::ConfigShow < Hatchbox::Command
  describe "config",
    summary: "display the config vars set on an app",
    aliases: ["config:list"]

  def call
    none!
    names = app.env_var_names

    ui.header("#{label} Config Vars")
    names.each { |name| puts(name.green) }
    0
  end
end

class Hatchbox::ConfigGet < Hatchbox::Command
  describe "config:get",
    summary: "check whether a config var is set",
    usage: "config:get KEY"

  def call
    key = one_positional("KEY").upcase
    raise Hatchbox::Error, "#{key} is set on #{label}, but Hatchbox never returns config var values." if app.env_var_names.include?(key)

    raise Hatchbox::Error, "#{key} is not set on #{label}."
  end
end

class Hatchbox::ConfigSet < Hatchbox::Command
  USABLE = /\A[A-Z0-9_]+\z/.freeze

  describe "config:set",
    summary: "set one or more config vars",
    usage: "config:set KEY1=VALUE1 [KEY2=VALUE2 ...]"

  def call
    usage_error("Must specify KEY and VALUE to set.") if positionals.empty?
    vars = positionals.map { |pair| pair_for(pair) }
    names = vars.map { |var| var["name"] }
    ui.action("Setting #{names.join(", ")} on #{label}") { client.put("/apps/#{app_id}/env_vars", body: { "env_vars" => vars }) }
    ui.styled_hash(vars.map { |var| [var["name"].green, var["value"]] })
    0
  end

  private

  def pair_for(text)
    name, separator, value = text.partition("=")
    usage_error("#{text} is invalid. Must be in the format KEY=VALUE.") if separator.empty? || name.empty?

    { "name" => Hatchbox::ConfigSet.usable(name), "value" => value }
  end

  def self.usable(name)
    cleaned = name.strip.upcase
    raise Hatchbox::Error, "#{name} is not a name Hatchbox takes. Use letters, numbers and underscores." unless cleaned =~ USABLE

    cleaned
  end
end

class Hatchbox::ConfigUnset < Hatchbox::Command
  describe "config:unset",
    summary: "unset one or more config vars",
    usage: "config:unset KEY1 [KEY2 ...]",
    aliases: ["config:remove"]

  def call
    usage_error("Must specify KEY to unset.") if positionals.empty?
    names = positionals.map { |name| Hatchbox::ConfigSet.usable(name) }
    ui.action("Unsetting #{names.join(", ")} on #{label}") { client.delete("/apps/#{app_id}/env_vars", body: { "env_vars" => names }) }
    0
  end
end

class Hatchbox::Maintenance < Hatchbox::Command
  describe "maintenance",
    summary: "display the current maintenance status of an app"

  def call
    none!
    puts(ui.yes_no(app.details["maintenance"]))
    0
  end
end

class Hatchbox::MaintenanceOn < Hatchbox::Command
  describe "maintenance:on",
    summary: "put the app into maintenance mode"

  def call
    none!
    ui.action("Enabling maintenance mode for #{label}") { client.post("/apps/#{app_id}/maintenance") }
    0
  end
end

class Hatchbox::MaintenanceOff < Hatchbox::Command
  describe "maintenance:off",
    summary: "take the app out of maintenance mode"

  def call
    none!
    ui.action("Disabling maintenance mode for #{label}") { client.delete("/apps/#{app_id}/maintenance") }
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
      ui.header("#{account["name"]} Git Providers")
      next puts("None connected.") if rows.empty?

      ui.table(rows, [["Provider", ->(row) { row["provider"] }], ["Name", ->(row) { row["name"] }], ["Id", ->(row) { row["id"] }]])
    end
    0
  end
end

module Hatchbox::Activity
  NAMESPACES = ["Apps"].freeze

  class << self
    def change(row)
      name = row["name"].to_s
      text = name == "Apps::Deploy" ? deploy(row) : humanize(name)
      description = row["description"].to_s.strip
      return text if name == "Apps::Deploy" || description.empty?

      "#{text}: #{description}"
    end

    def state(row)
      raw = row["state"].to_s
      return "" if raw == "completed"
      return raw.red if ["failed", "aborted"].include?(raw)

      raw.yellow
    end

    def deploy?(row)
      row["name"].to_s == "Apps::Deploy"
    end

    def humanize(name)
      parts = name.split("::")
      parts.shift if parts.length > 1 && NAMESPACES.include?(parts.first)
      words = parts.map { |part| part.gsub(/([a-z0-9])([A-Z])/, '\1 \2').tr("_", " ").downcase }
      return "#{words.first.to_s[0].to_s.upcase}#{words.first.to_s[1..-1]}" if words.length < 2

      last = words.last
      "#{last[0].upcase}#{last[1..-1]} #{words[-2]}"
    end

    def rows(list, limit: 50)
      list.map do |row|
        change = change(row)
        change = "#{change[0, limit - 3]}..." if change.length > limit
        [row["id"].to_s, change, row["username"].to_s, Hatchbox::Ui.date(row["created_at"]).to_s, state(row)]
      end
    end

    private

    def deploy(row)
      sha = row["commit_sha"].to_s
      subject = row["description"].to_s.strip.split("\n").first.to_s
      ["Deploy", sha.empty? ? nil : sha[0, 7], subject.empty? ? nil : subject].compact.join(" ")
    end
  end
end

class Hatchbox::Command
  private

  def follow_deploy(log_id)
    result = operation.stream(log_id)
    $stdout.puts
    ui.action("Verifying deploy") { |step| step.status = result.ok? ? "done" : ui.paint(result.state.to_s, 31) }
    return 0 if result.ok?

    ui.error("The deploy #{result.state}. Read it again with hatchbox releases:output #{log_id}")
    1
  end

  def resolve_log(wanted, kind: nil)
    text = wanted.to_s
    return text if text =~ /\A[0-9]+\z/

    names = {
      "deploy" => "Apps::Deploy",
      "deploys" => "Apps::Deploy",
      "restart" => "Apps::Restart",
      "restarts" => "Apps::Restart"
    }
    name = Hatchbox.blank?(text) ? kind : names[text]
    raise Hatchbox::Error, "#{text} is not a release id. hatchbox releases lists them." if !Hatchbox.blank?(text) && name.nil?

    rows = client.get("/apps/#{app_id}/logs?limit=100").json || []
    found = name ? rows.find { |row| row["name"] == name } : rows.first
    raise Hatchbox::Error, "#{label} has no #{name ? Hatchbox::Activity.humanize(name).downcase : "releases"} on record." unless found

    found["id"].to_s
  end

  def dyno_server(dyno:, server:)
    return nil if Hatchbox::SshTarget.pinned?(session)
    return app.formation.find_dyno(dyno).server unless Hatchbox.blank?(dyno)

    app.formation.find_server(server)
  end

  def ssh_target(dyno: nil, server: nil)
    Hatchbox::SshTarget.new(session: session, server: dyno_server(dyno: dyno, server: server))
  end
end

class Hatchbox::Ps < Hatchbox::Command
  describe "ps",
    summary: "list processes for an app",
    usage: "ps [TYPE [TYPE ...]]"

  def call
    formation = app.formation
    pool = positionals.empty? ? app.processes : positionals.map { |name| formation.find_process(name) }
    pool = pool.sort_by { |row| row["name"].to_s }

    if pool.empty?
      puts("No processes on #{label}. Add one with hatchbox ps:create.")
      return 0
    end

    pool.each_with_index do |process, index|
      puts if index.positive?
      dynos = formation.dynos(process)
      ui.header("#{process["name"]} (#{formation.where(process)}): #{process["start_command"]} (#{dynos.length})")
      state = process["active"] ? "enabled".green : "disabled".yellow
      rows = dynos.map { |dyno| ["#{dyno.name}:", state, dyno.server["name"], dyno.server["public_ip"]] }
      ui.columns(rows)
      puts("No active server carries #{formation.where(process)}.".dim) if dynos.empty?
    end
    0
  end

end

class Hatchbox::PsInfo < Hatchbox::Command
  describe "ps:info",
    summary: "show everything about one process",
    usage: "ps:info TYPE"

  def call
    process = app.formation.find_process(one_positional("TYPE"))

    ui.header("#{process["name"]} on #{label}")
    ui.styled_hash([
      ["Id", process["id"].to_s],
      ["State", process["active"] ? "enabled" : "disabled"],
      ["Runs On", app.formation.where(process)],
      ["Dynos", app.formation.dynos(process).map { |dyno| "#{dyno.name} #{dyno.server["name"]}" }],
      ["Start", process["start_command"]],
      ["Stop", process["stop_command"]],
      ["Reload", process["reload_command"]],
      ["Socket", ui.yes_no(process["socket"])],
      ["Systemd Type", process["systemd_type"]],
      ["Unit", "#{app.name}-#{process["name"]}.service"],
      ["On Deploy", process["restart_on_deploy"] ? "restarts" : "left alone"],
      ["AppSignal", ui.yes_no(process["appsignal"])],
      ["AppSignal Options", process["appsignal_options"]],
      ["Created", ui.date(process["created_at"])],
      ["Updated", ui.date(process["updated_at"])]
    ])
    0
  end
end

class Hatchbox::PsRestart < Hatchbox::Command
  describe "ps:restart",
    summary: "restart every process, or one process type",
    usage: "ps:restart [TYPE]",
    aliases: ["restart"],
    flags: [WAIT_FLAG]

  def call
    usage_error("One process type at a time.") if positionals.length > 1
    if positionals.empty?
      log_id = (client.post("/apps/#{app_id}/restart").json || {})["id"]
      return queued("Restarting all processes on #{label}", log_id)
    end

    process = app.formation.find_process(positionals.first.sub(/\.[0-9]+\z/, ""))
    log_id = (client.post("/apps/#{app_id}/processes/#{process["id"]}/restart").json || {})["id"]
    queued("Restarting #{process["name"]} on #{label}", log_id)
  end
end

class Hatchbox::PsStop < Hatchbox::Command
  describe "ps:stop",
    summary: "turn a process off and leave it off",
    usage: "ps:stop TYPE",
    aliases: ["ps:kill"],
    flags: [WAIT_FLAG]

  def call
    process = app.formation.find_process(one_positional("TYPE").sub(/\.[0-9]+\z/, ""))
    data = client.delete("/apps/#{app_id}/processes/#{process["id"]}/activation").json || {}
    toggled(data: data, message: "Stopping #{process["name"]} on #{label}", already: "it was already off")
  end

  private

  def toggled(data:, message:, already:)
    log_id = data["log_id"]
    if Hatchbox.blank?(log_id)
      ui.action(message) { |step| step.status = "done, #{already}" }
      return 0
    end

    queued(message, log_id)
  end
end

class Hatchbox::PsStart < Hatchbox::PsStop
  describe "ps:start",
    summary: "turn a stopped process back on",
    usage: "ps:start TYPE",
    flags: [WAIT_FLAG]

  def call
    process = app.formation.find_process(one_positional("TYPE").sub(/\.[0-9]+\z/, ""))
    data = client.post("/apps/#{app_id}/processes/#{process["id"]}/activation").json || {}
    toggled(data: data, message: "Starting #{process["name"]} on #{label}", already: "it was already on")
  end
end

module Hatchbox::ProcessFields
  NAME = /\A[A-Za-z0-9_-]+\z/.freeze

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
    [nil, "--[no-]appsignal", "run it under appsignal-wrap, which needs AppSignal connected"],
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
    raise Hatchbox::Error, "A process runs on --roles or on one --server, not both." if body.key?("roles") && body.key?("server_id") && body["roles"].any?
    raise Hatchbox::Error, "#{body["name"]} is not a name Hatchbox takes. Use letters, numbers, hyphens and underscores." if body.key?("name") && body["name"] !~ NAME

    body
  end

  def server_id_for(wanted)
    return wanted if wanted.to_s =~ /\A[0-9]+\z/

    found = app.servers.find { |server| server["name"].to_s.casecmp?(wanted.to_s) }
    raise Hatchbox::Error, "No server called #{wanted} on #{label}'s cluster.\n#{app.formation.server_listing}" unless found

    found["id"]
  end

  def show(process)
    ui.styled_hash([
      ["Id", process["id"].to_s],
      ["Runs On", app.formation.where(process)],
      ["Start", process["start_command"]],
      ["Stop", process["stop_command"]],
      ["Reload", process["reload_command"]],
      ["Systemd Type", process["systemd_type"]],
      ["On Deploy", process["restart_on_deploy"] ? "restarts" : "left alone"]
    ])
  end
end

class Hatchbox::PsCreate < Hatchbox::Command
  include Hatchbox::ProcessFields

  describe "ps:create",
    summary: "add a process to the app",
    usage: "ps:create NAME --start COMMAND (--roles LIST | --server SERVER)",
    flags: Hatchbox::ProcessFields::FLAGS + [WAIT_FLAG]

  def call
    usage_error("Only one name at a time.") if positionals.length > 1
    body = process_body
    body["name"] = positionals.first if positionals.any? && Hatchbox.blank?(body["name"])
    usage_error("Must specify NAME.") if Hatchbox.blank?(body["name"])
    usage_error("Must specify --start, the command that runs.") if Hatchbox.blank?(body["start_command"])
    usage_error("Must specify --roles or --server, so Hatchbox knows where to run it.") if Array(body["roles"]).empty? && Hatchbox.blank?(body["server_id"])
    raise Hatchbox::Error, "#{body["name"]} is not a name Hatchbox takes. Use letters, numbers, hyphens and underscores." unless body["name"] =~ Hatchbox::ProcessFields::NAME

    data = client.post("/apps/#{app_id}/processes", body: { "process" => body }).json || {}
    code = Hatchbox.blank?(data["log_id"]) ? 0 : queued("Creating #{body["name"]} on #{label}", data["log_id"])
    show(data)
    code
  end
end

class Hatchbox::PsUpdate < Hatchbox::Command
  include Hatchbox::ProcessFields

  describe "ps:update",
    summary: "change a process",
    usage: "ps:update TYPE [--start COMMAND] [--roles LIST] ...",
    flags: Hatchbox::ProcessFields::FLAGS + [WAIT_FLAG]

  def call
    process = app.formation.find_process(one_positional("TYPE"))
    body = process_body
    usage_error("Nothing to change. See hatchbox help ps:update.") if body.empty?

    message = "Updating #{process["name"]} on #{label}"
    data = client.patch("/apps/#{app_id}/processes/#{process["id"]}", body: { "process" => body }).json || {}
    return queued(message, data["log_id"]) unless Hatchbox.blank?(data["log_id"])

    ui.action(message) { nil }
    0
  end
end

class Hatchbox::PsDestroy < Hatchbox::Command
  describe "ps:destroy",
    summary: "stop a process and delete it from every server",
    usage: "ps:destroy TYPE",
    flags: [[nil, "--confirm TYPE", "the process name, to skip the prompt"], WAIT_FLAG]

  def call
    process = app.formation.find_process(one_positional("TYPE"))
    name = process["name"].to_s
    confirm(expected: name, lines: ["This command will stop #{name} and remove its systemd unit from every server on #{label}."])
    log_id = (client.delete("/apps/#{app_id}/processes/#{process["id"]}").json || {})["id"]
    queued("Destroying #{name} on #{label}", log_id)
  end
end

class Hatchbox::Logs < Hatchbox::Command
  describe "logs",
    summary: "display recent log output",
    flags: [
      ["-n", "--num NUM", "number of lines to display", Integer],
      ["-t", "--tail", "continually stream logs"],
      ["-f", "--follow", "same as --tail"],
      ["-d", "--dyno DYNO", "only this process or copy of it, like sidekiq or server.2, or a run.ID"],
      ["-p", "--process-type TYPE", "only this process type"],
      [nil, "--ps TYPE", "same as --process-type"],
      ["-s", "--source SOURCE", "only app lines, or only systemd lines about starting and stopping"],
      [nil, "--server SERVER", "only the server with this name, id or role"],
      [nil, "--since WHEN", "only lines since this, anything journalctl --since takes, like '1 hour ago'"],
      [nil, "--units", "list the systemd units it would read on each server, and stop"],
      [nil, "--force-colors", "force use of colors even on non-tty output"]
    ]

  def call
    usage_error("One process at a time.") if positionals.length > 1
    wanted = positionals.first
    raise Hatchbox::Error, "logs reads the running app. A Hatchbox log id goes to hatchbox releases:output #{wanted}" if wanted.to_s =~ /\A[0-9]+\z/

    source = options[:source]
    raise Hatchbox::Error, "--source takes app or systemd." unless Hatchbox.blank?(source) || ["app", "systemd"].include?(source)

    Hatchbox::LogReader.new(
      plans: plans(type: options[:process_type] || options[:ps] || wanted),
      lines: options[:num] || 100,
      follow: options[:tail] || options[:follow],
      since: options[:since],
      source: source,
      units_only: options[:units],
      colors: options[:force_colors] || Hatchbox.color?
    ).run
  end

  private

  def plans(type:)
    dyno = options[:dyno].to_s
    return run_plans(dyno) if dyno.start_with?("run.")

    formation = app.formation
    raise Hatchbox::Error, "#{label} has no processes, so there is no journal to read." if formation.processes.empty?

    dynos = pick(formation: formation, dyno: dyno, type: type)
    return [pinned_plan(dynos)] if Hatchbox::SshTarget.pinned?(session)

    unless Hatchbox.blank?(options[:server])
      server = formation.find_server(options[:server])
      dynos = dynos.select { |row| row.server["id"] == server["id"] }
      raise Hatchbox::Error, "None of those processes run on #{server["name"]}." if dynos.empty?
    end
    raise Hatchbox::Error, "Those processes run on no active server." if dynos.empty?

    dynos.group_by { |row| row.server["id"] }.map do |_id, group|
      Hatchbox::LogReader::Plan.new(
        target: Hatchbox::SshTarget.new(session: session, server: group.first.server),
        units: group.to_h { |row| [unit(row.process), { name: row.name, color: color(row.process) }] },
        identifiers: {}
      )
    end
  end

  def pick(formation:, dyno:, type:)
    return [formation.find_dyno(dyno)] if dyno =~ /\.[0-9]+\z/
    return formation.dynos(formation.find_process(dyno)) unless dyno.empty?
    return formation.dynos(formation.find_process(type)) unless Hatchbox.blank?(type)

    formation.dynos
  end

  def pinned_plan(dynos)
    units = {}
    pool = dynos.empty? ? app.formation.processes.map { |process| Hatchbox::Formation::Dyno.new(process, {}, 1) } : dynos
    pool.each { |row| units[unit(row.process)] ||= { name: "#{row.type}.1", color: color(row.process) } }
    Hatchbox::LogReader::Plan.new(target: Hatchbox::SshTarget.new(session: session), units: units, identifiers: {})
  end

  def run_plans(dyno)
    ident = "#{app.name}-#{dyno.tr(".", "-")}"
    servers = Hatchbox::SshTarget.pinned?(session) ? [nil] : run_servers
    servers.map do |server|
      Hatchbox::LogReader::Plan.new(
        target: Hatchbox::SshTarget.new(session: session, server: server),
        units: {},
        identifiers: { ident => { name: dyno, color: 34 } }
      )
    end
  end

  def run_servers
    return [app.formation.find_server(options[:server])] unless Hatchbox.blank?(options[:server])

    app.formation.app_servers
  end

  def unit(process)
    "#{app.name}-#{process["name"]}.service"
  end

  def color(process)
    index = app.processes.index(process) || 0
    Hatchbox::LogReader::PALETTE[index % Hatchbox::LogReader::PALETTE.length]
  end
end

class Hatchbox::Run < Hatchbox::Command
  describe "run",
    summary: "run a command on one of the app's servers",
    usage: "run COMMAND",
    lenient: true,
    flags: [
      ["-e", "--env ENV", "environment variables to set, like FOO=bar;BAZ=qux", :many],
      ["-s", "--server SERVER", "the server to run on, by name, id or role"],
      ["-d", "--dyno DYNO", "run on the server this copy of a process is on, like sidekiq.2"],
      [nil, "--no-tty", "force the command to not run in a tty"],
      ["-x", "--exit-code", "passthrough the exit code of the remote command, which it always does"]
    ]

  def call
    command = (positionals + passthru).join(" ")
    usage_error("Must specify COMMAND.") if command.strip.empty?

    target = ssh_target(dyno: options[:dyno], server: options[:server])
    script = [exports, script_for(command: command, target: target)].reject { |part| part.empty? }.join("\n")
    ui.action("Running `#{command}` on #{label}") { |step| step.status = "up, #{target.label}" }
    Hatchbox.run(target.ssh(command: target.login_shell(script), tty: tty?))
  end

  private

  def tty?
    !options[:no_tty] && $stdin.tty? && $stdout.tty?
  end

  def exports
    pairs = Array(options[:env]).flat_map { |text| text.split(";") }.map { |pair| pair.strip }.reject { |pair| pair.empty? }
    pairs.map do |pair|
      name, separator, value = pair.partition("=")
      usage_error("#{pair} is invalid. --env takes KEY=VALUE pairs separated by semicolons.") if separator.empty? || name !~ /\A[A-Za-z_][A-Za-z0-9_]*\z/

      "export #{name}=#{Shellwords.escape(value)}"
    end.join("\n")
  end

  def rails?(command)
    ["rails", "bin/rails"].include?(command) || command.start_with?("rails ", "bin/rails ")
  end

  def script_for(command:, target:)
    return "#{target.enter(separator: "\n")}#{command}" unless rails?(command)

    "#{target.enter_or_stop}\nexec bin/rails #{command.sub(%r{\Abin/}, "").sub(/\Arails/, "").strip}"
  end
end

class Hatchbox::RunDetached < Hatchbox::Run
  describe "run:detached",
    summary: "run a command on a server in the background",
    usage: "run:detached COMMAND",
    lenient: true,
    flags: [
      ["-e", "--env ENV", "environment variables to set, like FOO=bar;BAZ=qux", :many],
      ["-s", "--server SERVER", "the server to run on, by name, id or role"],
      ["-d", "--dyno DYNO", "run on the server this copy of a process is on, like sidekiq.2"]
    ]

  def call
    command = (positionals + passthru).join(" ")
    usage_error("Must specify COMMAND.") if command.strip.empty?

    target = ssh_target(dyno: options[:dyno], server: options[:server])
    dyno = "run.#{Time.now.utc.strftime("%Y%m%d%H%M%S")}"
    ident = "#{app.name}-#{dyno.tr(".", "-")}"
    inner = rails?(command) ? "exec bin/rails #{command.sub(%r{\Abin/}, "").sub(/\Arails/, "").strip}" : command
    script = [
      rails?(command) ? target.enter_or_stop : target.enter(separator: " || true"),
      exports,
      "setsid nohup systemd-cat -t #{Shellwords.escape(ident)} bash -lc #{Shellwords.escape(inner)} </dev/null >/dev/null 2>&1 &",
      "echo started"
    ].reject { |part| part.empty? }.join("\n")
    code = nil
    ui.action("Running `#{command}` on #{label}") do |step|
      code = Hatchbox.run(target.ssh(command: target.login_shell(script)))
      step.status = code.zero? ? "done, #{dyno}" : ui.paint("failed", 31)
    end
    return code unless code.zero?

    puts("Run hatchbox logs --app #{app.slug || app_id} --dyno #{dyno} to view the output.")
    0
  end
end

class Hatchbox::PsExec < Hatchbox::Command
  describe "ps:exec",
    summary: "open an SSH session on one of the app's servers",
    usage: "ps:exec [COMMAND]",
    aliases: ["ssh"],
    flags: [
      ["-d", "--dyno DYNO", "the server this copy of a process is on, like sidekiq.2"],
      ["-s", "--server SERVER", "the server, by name, id or role"]
    ]

  def call
    usage_error("Only one command at a time, quote it as one argument.") if positionals.length > 1
    command = positionals.first
    target = ssh_target(dyno: options[:dyno], server: options[:server])
    $stderr.puts("Connecting to #{target.label} on #{label}...") if command.nil?
    Hatchbox.run(target.ssh(command: "#{target.enter(separator: "; ")}#{command || "exec ${SHELL:-/bin/bash} -l"}", tty: command.nil?, extra: passthru))
  end
end

class Hatchbox::PsForward < Hatchbox::Command
  describe "ps:forward",
    summary: "forward traffic on a local port to a server",
    usage: "ps:forward PORT[,PORT...]",
    flags: [
      ["-p", "--local-port PORT", "local port to use, comma separated to match PORT"],
      ["-d", "--dyno DYNO", "the server this copy of a process is on"],
      ["-s", "--server SERVER", "the server, by name, id or role"]
    ]

  def call
    remote = one_positional("PORT").split(",")
    local = Hatchbox.blank?(options[:local_port]) ? remote : options[:local_port].split(",")
    usage_error("--local-port needs as many ports as PORT has.") unless local.length == remote.length
    raise Hatchbox::Error, "Ports are numbers." unless (remote + local).all? { |port| port =~ /\A[0-9]+\z/ }

    target = ssh_target(dyno: options[:dyno], server: options[:server])
    forwards = local.zip(remote).flat_map { |mine, theirs| ["-L", "127.0.0.1:#{mine}:localhost:#{theirs}"] }
    $stderr.puts("SSH tunnel established.")
    local.zip(remote).each { |mine, theirs| $stderr.puts("Forwarding localhost:#{mine} to #{target.label}:#{theirs}") }
    $stderr.puts("Use CTRL+C to stop port forwarding")
    Hatchbox.run(target.ssh(extra: ["-N", "-o", "ExitOnForwardFailure=yes"] + forwards))
  end
end

class Hatchbox::PsSocks < Hatchbox::Command
  describe "ps:socks",
    summary: "launch a SOCKS proxy into one of the app's servers",
    flags: [
      ["-p", "--port PORT", "local port for the proxy, 1080 unless you say otherwise"],
      ["-d", "--dyno DYNO", "the server this copy of a process is on"],
      ["-s", "--server SERVER", "the server, by name, id or role"]
    ]

  def call
    none!
    port = options[:port] || "1080"
    target = ssh_target(dyno: options[:dyno], server: options[:server])
    $stderr.puts("SOCKSv5 proxy server started on port #{port}")
    $stderr.puts("Use CTRL+C to stop the proxy")
    Hatchbox.run(target.ssh(extra: ["-N", "-o", "ExitOnForwardFailure=yes", "-D", "127.0.0.1:#{port}"]))
  end
end

class Hatchbox::PsCopy < Hatchbox::Command
  describe "ps:copy",
    summary: "copy a file off one of the app's servers",
    usage: "ps:copy FILE",
    flags: [
      ["-o", "--output FILE", "where to write it, the file's own name unless you say otherwise"],
      ["-d", "--dyno DYNO", "the server this copy of a process is on"],
      ["-s", "--server SERVER", "the server, by name, id or role"]
    ]

  def call
    file = one_positional("FILE")
    output = options[:output] || File.basename(file)
    raise Hatchbox::Error, "#{output} already exists. Pick another name with --output." if File.exist?(output) && options[:output].nil?

    target = ssh_target(dyno: options[:dyno], server: options[:server])
    remote = file.start_with?("/") || target.app_dir.nil? ? file : File.join(target.app_dir, file)
    argv = ["scp", "-q", "-P", target.port.to_s] + Hatchbox.ssh_options + ["#{target.address}:#{Shellwords.escape(remote)}", output]
    code = nil
    ui.action("Copying #{file} to #{output}") do |step|
      code = Hatchbox.run(argv)
      step.status = code.zero? ? "done" : ui.paint("failed", 31)
    end
    code
  end
end

class Hatchbox::Deploy < Hatchbox::Command
  describe "deploy",
    summary: "deploy the app's branch, or one commit, and stream the build",
    flags: [
      [nil, "--sha SHA", "deploy this commit instead of the tip of the branch"],
      WAIT_FLAG,
      [nil, "--no-follow", "same as --no-wait"],
      [nil, "--watch", "stream the log, which it does anyway"],
      [nil, "--status", "same as hatchbox status"]
    ]

  def call
    return Hatchbox::Status.call(session: session, args: []) if options[:status] || positionals == ["status"]

    none!
    sha = options[:sha]
    ref = Hatchbox.blank?(sha) ? app.details["branch"] : sha[0, 7]
    log_id = nil
    ui.action("Deploying #{ref} to #{label}") do |step|
      log_id = (client.post("/apps/#{app_id}/deploy", body: Hatchbox.blank?(sha) ? nil : { "sha" => sha }).json || {})["id"]
      raise Hatchbox::Error, "Hatchbox accepted the deploy but returned no log id." if Hatchbox.blank?(log_id)

      step.status = options[:no_wait] || options[:no_follow] ? "done, queued as #{log_id}" : "queued, release #{log_id}"
    end
    return 0 if options[:no_wait] || options[:no_follow]

    follow_deploy(log_id)
  end
end

class Hatchbox::Status < Hatchbox::Command
  describe "status",
    summary: "show the latest deploy and its output",
    hidden: false

  def call
    none!
    log = operation.fetch(resolve_log(nil, kind: "Apps::Deploy"))
    ui.header("#{label} Deploy #{log["id"]}")
    Hatchbox::ReleasesInfo.describe_log(log)
    puts
    return follow_deploy(log["id"]) unless Hatchbox::FINISHED.include?(log["state"].to_s)

    operation.print_log(log)
    log["state"] == "completed" ? 0 : 1
  end
end

class Hatchbox::Releases < Hatchbox::Command
  describe "releases",
    summary: "display the app's release history",
    flags: [["-n", "--num NUM", "number of releases to display", Integer], [nil, "--page PAGE", "page of older releases", Integer]]

  def call
    none!
    limit = options[:num] || 15
    rows = client.get("/apps/#{app_id}/logs?page=#{options[:page] || 1}&limit=#{limit}").json || []

    current = rows.find { |row| Hatchbox::Activity.deploy?(row) && row["state"] == "completed" }
    ui.header("#{label} Releases#{current ? " - Current: #{current["id"]}" : ""}")
    return puts("No releases on record.") if rows.empty?

    puts
    ui.columns(Hatchbox::Activity.rows(rows))
    0
  end
end

class Hatchbox::ReleasesInfo < Hatchbox::Command
  describe "releases:info",
    summary: "view detailed information for a release",
    usage: "releases:info [RELEASE]"

  def self.describe_log(log)
    Hatchbox::Ui.styled_hash([
      ["Change", Hatchbox::Activity.change(log)],
      ["By", log["username"]],
      ["When", Hatchbox::Ui.date(log["created_at"])],
      ["State", log["state"]],
      ["Commit", log["commit_sha"]],
      ["Started", Hatchbox::Ui.date(log["started_at"])],
      ["Completed", Hatchbox::Ui.date(log["completed_at"])],
      ["Duration", Hatchbox::Ui.duration(log["started_at"], log["completed_at"])],
      ["Servers", (log["child_logs"] || []).map { |child| "#{child["loggable_id"]} #{child["state"]}" }]
    ])
  end

  def call
    usage_error("One release at a time.") if positionals.length > 1
    log = operation.fetch(resolve_log(positionals.first))

    ui.header("Release #{log["id"]}")
    self.class.describe_log(log)
    0
  end
end

class Hatchbox::ReleasesOutput < Hatchbox::Command
  describe "releases:output",
    summary: "view the output of a release, following it while it runs",
    usage: "releases:output [RELEASE]",
    aliases: ["builds:output"]

  def call
    usage_error("One release at a time.") if positionals.length > 1
    log_id = resolve_log(positionals.first, kind: default_kind)
    log = operation.fetch(log_id)
    unless Hatchbox::FINISHED.include?(log["state"].to_s)
      result = operation.stream(log_id)
      return result.ok? ? 0 : 1
    end

    operation.print_log(log)
    log["state"] == "completed" ? 0 : 1
  end

  private

  def default_kind
    nil
  end
end

class Hatchbox::ReleasesRollback < Hatchbox::Command
  describe "releases:rollback",
    summary: "redeploy the commit of an earlier release",
    usage: "releases:rollback [RELEASE]",
    aliases: ["rollback"],
    flags: [WAIT_FLAG]

  def call
    usage_error("One release at a time.") if positionals.length > 1
    deploys = (client.get("/apps/#{app_id}/logs?limit=100").json || []).select { |row| Hatchbox::Activity.deploy?(row) && row["state"] == "completed" && !Hatchbox.blank?(row["commit_sha"]) }
    live = deploys.first
    chosen = positionals.empty? ? previous(deploys) : lookup(positionals.first)
    sha = chosen["commit_sha"].to_s
    log_id = nil
    ui.action("Rolling back #{label} to #{chosen["id"]} (#{sha[0, 7]})") do |step|
      log_id = (client.post("/apps/#{app_id}/deploy", body: { "sha" => sha }).json || {})["id"]
      step.status = options[:no_wait] ? "done, queued as #{log_id}" : "queued, release #{log_id}"
    end
    ui.warning("Rollback redeploys that commit. Config vars, processes and databases are left as they are.")
    ui.warning("To undo, run: hatchbox releases:rollback #{live["id"]}") if live
    return 0 if options[:no_wait]

    follow_deploy(log_id)
  end

  private

  def previous(deploys)
    current = app.details["last_deploy_sha"].to_s
    found = deploys.find { |row| row["commit_sha"].to_s != current }
    raise Hatchbox::Error, "There is no earlier successful deploy of a different commit in the last 100 releases." unless found

    found
  end

  def lookup(wanted)
    log = operation.fetch(resolve_log(wanted))
    raise Hatchbox::Error, "Release #{log["id"]} is not a deploy, so there is no commit to roll back to." unless Hatchbox::Activity.deploy?(log) && !Hatchbox.blank?(log["commit_sha"])
    raise Hatchbox::Error, "Release #{log["id"]} belongs to another app." unless log["loggable_id"].to_s == app_id.to_s

    log
  end
end

class Hatchbox::Builds < Hatchbox::Command
  describe "builds",
    summary: "list the app's deploys",
    flags: [["-n", "--num NUM", "number of builds to display", Integer]]

  def call
    none!
    limit = options[:num] || 15
    rows = []
    url = "/apps/#{app_id}/logs?limit=100"
    pages = 0
    while url && rows.length < limit && pages < 10
      response = client.get(url)
      rows.concat(Array(response.json).select { |row| Hatchbox::Activity.deploy?(row) })
      url = response.next_page
      pages += 1
    end
    rows = rows.first(limit)

    ui.header("#{label} Builds")
    return puts("No builds on record.") if rows.empty?

    ui.columns(rows.map do |row|
      state = row["state"].to_s
      painted = state == "completed" ? "succeeded".green : (["failed", "aborted"].include?(state) ? state.red : state.yellow)
      [row["id"].to_s, painted, row["commit_sha"].to_s[0, 7], row["username"].to_s, Hatchbox::Ui.date(row["created_at"]).to_s, row["description"].to_s.split("\n").first.to_s[0, 50]]
    end)
    0
  end
end

class Hatchbox::BuildsInfo < Hatchbox::ReleasesInfo
  describe "builds:info",
    summary: "view detailed information for a build",
    usage: "builds:info [BUILD]"

  def call
    usage_error("One build at a time.") if positionals.length > 1
    log = operation.fetch(resolve_log(positionals.first, kind: "Apps::Deploy"))

    ui.header("Build #{log["id"]}")
    Hatchbox::ReleasesInfo.describe_log(log)
    0
  end
end

class Hatchbox::Domains < Hatchbox::Command
  describe "domains",
    summary: "list the app's domains"

  def call
    none!
    rows = app.domains

    ui.header("#{label} Custom Domains")
    return puts("#{label} has no domain names.") if rows.empty?

    ui.table(rows, [["Domain Name", ->(row) { row["name"] }], ["Created", ->(row) { ui.short_date(row["created_at"]) }]])
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
    fronts = servers.select { |server| Array(server["roles"]).include?("load_balancer") }
    fronts = servers.select { |server| Array(server["roles"]).include?("web") } if fronts.empty?
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
    name = one_positional("HOSTNAME")
    ui.action("Adding #{name} to #{label}") { client.post("/apps/#{app_id}/domains", body: { "domain" => { "name" => name } }) }
    ips = targets
    ui.warning("Configure your app's DNS provider to point #{name} at #{ui.list(ips)}") if ips.any?
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
    name = one_positional("HOSTNAME")
    ui.action("Removing #{name} from #{label}") { client.delete(domain_path(name)) }
    0
  end
end

class Hatchbox::DomainsInfo < Hatchbox::Command
  include Hatchbox::DomainPaths

  describe "domains:info",
    summary: "show one of the app's domains",
    usage: "domains:info HOSTNAME"

  def call
    name = one_positional("HOSTNAME")
    row = client.get(domain_path(name)).json || {}

    ui.header(row["name"].to_s)
    ui.styled_hash([["Id", row["id"].to_s], ["Created", ui.date(row["created_at"])], ["Updated", ui.date(row["updated_at"])], ["Points At", targets]])
    0
  end
end

class Hatchbox::DomainsUpdate < Hatchbox::Command
  include Hatchbox::DomainPaths

  describe "domains:update",
    summary: "rename one of the app's domains",
    usage: "domains:update HOSTNAME NEWHOSTNAME"

  def call
    usage_error("Must specify HOSTNAME and NEWHOSTNAME.") unless positionals.length == 2

    old, name = positionals
    ui.action("Updating #{old} to #{name} on #{label}") { client.patch(domain_path(old), body: { "domain" => { "name" => name } }) }
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
    return puts("#{label} has no domain names.") if rows.empty?

    confirm(expected: app.name, lines: ["This command will remove #{ui.plural(rows.length, "domain")} from #{app.name}: #{rows.map { |row| row["name"] }.join(", ")}."])
    ui.action("Removing all domains from #{label}") { rows.each { |row| client.delete(domain_path(row["name"].to_s)) } }
    0
  end
end

module Hatchbox::DatabaseLookup
  private

  def account
    @account ||= begin
      found = session.catalog.account_for(app_id)
      raise Hatchbox::Error, "Could not tell which account #{label} is on." unless found

      found
    end
  end

  def database_clusters
    @database_clusters ||= session.catalog.database_clusters_for(account)
  end

  def database_cluster(id)
    database_clusters.find { |row| row["id"].to_s == id.to_s } || {}
  end

  def attached(wanted, engines: nil)
    pool = app.find_database(wanted, engines: engines)
    return pool.first if pool.length == 1

    kind = engines ? engines.join(" or ") : "database"
    if pool.empty?
      head = Hatchbox.blank?(wanted) ? "No #{kind} is attached to #{label}." : "No #{kind} called #{wanted} is attached to #{label}."
      raise Hatchbox::Error, app.databases.empty? ? head : "#{head}\n#{attachments_listing}"
    end

    raise Hatchbox::Error, "#{label} has more than one #{kind}, so name one:\n#{attachments_listing(pool)}"
  end

  def attachments_listing(pool = app.databases)
    pool.map { |record| "#{record["name"]} (#{record["engine"]}) as #{app.attachment_names(record).join(", ")}" }.join("\n")
  end

  def title_for(record)
    names = app.attachment_names(record)
    names.empty? ? record["name"].to_s : names.join(", ")
  end

  def backup_configuration(record)
    response = client.raw("GET", "/databases/#{record["id"]}/backup_configuration")
    return response.json if response.ok?

    { "error" => client.error_message(response) }
  end

  def backup_line(config)
    return config["error"] if config.key?("error")
    return "off" unless config["backup_enabled"]

    place = [config["backup_provider"], config["backup_bucket"]].compact.join(" ")
    kept = Hatchbox.blank?(config["backup_retention_period"]) ? "" : ", kept #{config["backup_retention_period"]}"
    "on, #{config["backup_frequency"]} to #{place}#{kept}"
  end
end

module Hatchbox::PgTools
  include Hatchbox::DatabaseLookup

  private

  def postgres(wanted)
    attached(wanted, engines: ["postgresql"])
  end

  def connection_text(record)
    public_uri = record["public_connection_uri"].to_s
    text = Hatchbox.blank?(public_uri) ? record["private_connection_uri"].to_s : public_uri
    raise Hatchbox::Error, "That database has no connection URI, which happens on sqlite." if Hatchbox.blank?(text)

    text
  end

  def tunnelled?(record)
    Hatchbox.blank?(record["public_connection_uri"]) && !options[:direct]
  end

  def with_connection(record)
    database = Hatchbox::Database.new(connection_text(record))
    tunnel = tunnelled?(record) ? Hatchbox::Tunnel.open(session: session, host: database.host, port: database.port) : nil
    host = tunnel ? "127.0.0.1" : database.host
    port = tunnel ? tunnel.local_port.to_s : database.port
    begin
      yield(database, host, port)
    ensure
      tunnel.close if tunnel
    end
  end

  def pg_environment(database:, dangerous:)
    env = { "PGPASSWORD" => database.password, "PGSSLMODE" => database.sslmode }
    return env if dangerous

    extra = [ENV["PGOPTIONS"], "-c default_transaction_read_only=on"].reject { |part| Hatchbox.blank?(part) }
    env.merge("PGOPTIONS" => extra.join(" "))
  end
end

class Hatchbox::Psql < Hatchbox::Command
  include Hatchbox::PgTools

  describe "pg:psql",
    summary: "open a psql shell to the database",
    usage: "pg:psql [DATABASE | SQL]",
    aliases: ["psql"],
    flags: [
      ["-c", "--command SQL", "SQL command to run"],
      ["-d", "--database NAME", "which postgresql database, when the app has more than one"],
      [nil, "--url", "print the connection URI instead of connecting"],
      [nil, "--direct", "connect straight to the database host instead of through an SSH tunnel"],
      [nil, "--dangerous", "a session that can write, which it cannot by default"]
    ]

  def call
    usage_error("Only one statement at a time, quote it as one argument.") if positionals.length > 1
    wanted = options[:database]
    sql = options[:command].to_s.sub(/\A=/, "")
    if positionals.any?
      if app.find_database(positionals.first, engines: ["postgresql"]).any? && Hatchbox.blank?(wanted)
        wanted = positionals.first
      else
        usage_error("Only one statement at a time, quote it as one argument.") unless sql.empty?
        sql = positionals.first
      end
    end

    record = postgres(wanted)
    return print_url(record) if options[:url]

    open_psql(record: record, sql: sql)
  end

  private

  def print_url(record)
    puts(connection_text(record))
    ui.warning("That host is the database's own machine, so the URI only works from the servers.") if Hatchbox.blank?(record["public_connection_uri"])
    0
  end

  def open_psql(record:, sql:)
    with_connection(record) do |database, host, port|
      $stderr.puts(options[:dangerous] ? "Read-write session".yellow : "Read-only session, pass --dangerous to write".dim)
      argv = ["psql", "-h", host, "-p", port, "-U", database.user, "-d", database.name]
      argv.concat(["-c", sql]) unless Hatchbox.blank?(sql)
      argv.concat(passthru)
      Hatchbox.run(argv, env: pg_environment(database: database, dangerous: options[:dangerous]))
    end
  end
end

class Hatchbox::PgInfo < Hatchbox::Command
  include Hatchbox::PgTools

  describe "pg:info",
    summary: "show database information",
    usage: "pg:info [DATABASE]",
    aliases: ["pg"]

  def call
    usage_error("One database at a time.") if positionals.length > 1
    pool = positionals.empty? ? app.databases.select { |record| record["engine"] == "postgresql" } : [postgres(positionals.first)]
    return puts("#{label} has no postgresql databases.") if pool.empty?

    pool.each_with_index do |record, index|
      puts if index.positive?
      cluster = database_cluster(record["database_cluster_id"])
      ui.header(title_for(record))
      ui.styled_hash([
        ["Add-on", record["name"]],
        ["Cluster", cluster["name"]],
        ["PG Version", cluster["version"]],
        ["Managed", cluster.key?("managed") ? (cluster["managed"] ? "yes" : "no") : nil],
        ["Region", cluster["region"]],
        ["Status", cluster.key?("active") ? (cluster["active"] ? "Available" : "Provisioning") : nil],
        ["Backups", cluster["managed"] ? "handled by your provider" : backup_line(backup_configuration(record))]
      ])
    end
    0
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
    raise Hatchbox::Error, "Flag #{flag} expects a value." if found.nil? || found == "--"

    found
  end

  def help(name)
    command = Hatchbox.blank?(name) ? nil : Hatchbox::Registry.find(name)
    raise Hatchbox::Error, "No help for #{name}.\nSee `hatchbox help` for a list of commands." if command.nil? && !Hatchbox.blank?(name)

    command ? usage(command) : listing
    0
  end

  def listing
    puts("Usage: hatchbox COMMAND [--app APP] [command-specific-options]")
    puts
    rows = Hatchbox::Registry.visible.sort_by { |klass| klass.meta[:name] }
    width = rows.map { |klass| klass.meta[:name].length }.max
    rows.each { |klass| puts("  #{klass.meta[:name].ljust(width)}  #  #{klass.meta[:summary]}") }
  end

  def usage(command)
    meta = command.meta
    puts("Usage: hatchbox #{meta[:usage]}")
    puts
    puts(" #{meta[:summary]}")
    flags = (meta[:app] ? Hatchbox::Command::APP_FLAGS : []) + meta[:flags]
    return if flags.empty?

    puts
    labels = flags.map { |short, long, _description, _type| short ? "#{short}, #{long}" : "    #{long}" }
    width = labels.map { |text| text.length }.max
    flags.each_with_index { |(_short, _long, description, _type), index| puts(" #{labels[index].ljust(width)}  #  #{description}") }
  end

  def unknown(name)
    raise Hatchbox::Error, "`#{name}` is not a hatchbox command.\nSee `hatchbox help` for a list of available commands."
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    exit(Hatchbox::Cli.call(ARGV).to_i)
  rescue Hatchbox::Error => e
    Hatchbox::Ui.error(e.message)
    exit(1)
  rescue Errno::EPIPE
    exit(0)
  rescue Interrupt
    $stderr.puts
    exit(130)
  end
end
