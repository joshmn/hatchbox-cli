#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "optparse"
require "pathname"
require "shellwords"

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

    def run(argv)
      started = system(*argv)
      raise Error, "#{argv.first} is required and is not installed" if started.nil?

      $?.exitstatus.to_i
    end
  end
end

class Hatchbox::Http

  METHODS = {
    "GET" => Net::HTTP::Get,
    "POST" => Net::HTTP::Post,
    "PUT" => Net::HTTP::Put,
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
    response = send_request(uri: uri, message: build(method: method, uri: uri, body: body))
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

  def send_request(uri:, message:)
    session = Net::HTTP.new(uri.host, uri.port)
    session.use_ssl = uri.scheme == "https"
    session.open_timeout = 15
    session.read_timeout = 30
    session.start { |open| open.request(message) }
  rescue StandardError => e
    raise Hatchbox::Error, "request to #{uri} failed, #{e.message}"
  end
end

class Hatchbox::Client

  def initialize(token:)
    @http = Hatchbox::Http.new(base: Hatchbox::API_BASE, token: token)
  end

  def get(path)
    ensure_ok(http.request(method: "GET", path: path))
  end

  def post(path, body: nil)
    ensure_ok(http.request(method: "POST", path: path, body: body))
  end

  def put(path, body: nil)
    ensure_ok(http.request(method: "PUT", path: path, body: body))
  end

  def delete(path, body: nil)
    ensure_ok(http.request(method: "DELETE", path: path, body: body))
  end

  private

  attr_reader :http

  def ensure_ok(response)
    return response if response.ok?

    raise Hatchbox::Error, "hatchbox said: #{error_message(response)}"
  end

  def error_message(response)
    data = response.json
    return "http #{response.code}" unless data.is_a?(Hash)

    detail = data["error"].to_s
    detail = Array(data["errors"]).join(", ") if detail.empty?
    detail.empty? ? "http #{response.code}" : detail
  end
end

class Hatchbox::App

  def initialize(client:, app_id:)
    @client = client
    @app_id = app_id
  end

  def details
    @details ||= client.get("/apps/#{app_id}").json || {}
  end

  def name
    details["name"].to_s
  end

  def last_deploy_sha
    details["last_deploy_sha"].to_s
  end

  def last_deploy_at
    details["last_deploy_at"].to_s
  end

  def servers
    @servers ||= load_servers
  end

  def server_name(id)
    match = servers.find { |server| server["id"].to_s == id.to_s }
    return "server #{id}" if match.nil? || Hatchbox.blank?(match["name"])

    match["name"]
  rescue Hatchbox::Error
    "server #{id}"
  end

  private

  attr_reader :client, :app_id

  def load_servers
    cluster = details["cluster_id"]
    raise Hatchbox::Error, "app #{app_id} is on no cluster, so there is no server to reach" if Hatchbox.blank?(cluster)

    (client.get("/clusters/#{cluster}").json || {})["servers"] || []
  end
end

class Hatchbox::Config

  attr_reader :path

  def initialize(path)
    @path = path.to_s
  end

  def exists?
    File.file?(path)
  end

  def get(key)
    settings[key]
  end

  def set(key:, value:)
    unless writable?
      warn("could not write #{key} to #{path}, it is not writable".yellow)
      return
    end

    written = false
    kept = lines.map do |line|
      next line unless setting_key(line) == key
      next nil if written

      written = true
      "#{key} = #{value}"
    end
    kept = kept.compact
    kept << "#{key} = #{value}" unless written
    write(kept)
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

  private

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
    io.print(question)
    io.flush
    answer = tty.gets
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

class Hatchbox::Context

  class << self

    def load(env_name)
      new(env_name).load
    end
  end

  attr_reader :config, :env, :app_id, :token

  def initialize(env_name)
    @env = env_name
  end

  def load
    @config = Hatchbox::Config.new(locate)
    @env = pick_env
    @app_id = pick_app
    @token = read_token
    raise Hatchbox::Error, "no api token. put 'token = ...' in #{Hatchbox::GLOBAL_CONFIG} or set HATCHBOX_API_TOKEN" if Hatchbox.blank?(token)

    self
  end

  def client
    @client ||= Hatchbox::Client.new(token: token)
  end

  def app
    @app ||= Hatchbox::App.new(client: client, app_id: app_id)
  end

  private

  def locate
    Pathname.new(Dir.pwd).ascend do |dir|
      candidate = dir.join(".hatchbox")
      return candidate.to_s if candidate.file? && candidate.to_s != Hatchbox::GLOBAL_CONFIG
    end
    raise Hatchbox::Error, "no .hatchbox found here or above #{Dir.pwd}. see hatchbox --help for the format"
  end

  def pick_env
    raise Hatchbox::Error, "#{config.path} names no app, so there is nothing to talk to. see hatchbox --help" if config.envs.empty?

    name = env
    name = ENV["HATCHBOX_ENV"] if Hatchbox.blank?(name)
    name = config.get("default") if Hatchbox.blank?(name)
    name = config.envs.first if Hatchbox.blank?(name) && config.envs.length == 1
    raise Hatchbox::Error, "#{config.path} has more than one environment and no default line, so pick one with -e\n\n#{listing}" if Hatchbox.blank?(name)

    name
  end

  def pick_app
    found = config.app_for(env)
    raise Hatchbox::Error, "no app is listed for #{env} in #{config.path}\n\nenvironments it does know about:\n#{listing}" if Hatchbox.blank?(found)

    found
  end

  def read_token
    from_env = ENV["HATCHBOX_API_TOKEN"]
    return from_env unless Hatchbox.blank?(from_env)

    scoped = global_config.get("token:#{env}")
    return scoped unless Hatchbox.blank?(scoped)

    global_config.get("token")
  end

  def global_config
    Hatchbox::Config.new(Hatchbox::GLOBAL_CONFIG)
  end

  def listing
    config.envs.map { |name| "  #{name}" }.join("\n")
  end
end

class Hatchbox::ServerPicker

  def initialize(app:, prompt: Hatchbox::Prompt.new)
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

    def resolve(context:, filter: nil)
      new(context: context, filter: filter).resolve
    end
  end

  attr_reader :host, :user, :port, :server

  def initialize(context:, filter: nil)
    @context = context
    @filter = filter
  end

  def resolve
    @host = config.get("ssh_host:#{env}")
    @user = config.get("ssh_user:#{env}")
    @port = config.get("ssh_port:#{env}")
    from_cluster if Hatchbox.blank?(host)
    @user = Hatchbox::DEFAULT_SSH_USER if Hatchbox.blank?(user)
    @port = Hatchbox::DEFAULT_SSH_PORT if Hatchbox.blank?(port)
    self
  end

  def address
    "#{user}@#{host}"
  end

  def server_label
    return nil unless server

    Hatchbox.blank?(server["name"]) ? "server" : server["name"]
  end

  def app_name
    context.app.name
  end

  private

  attr_reader :context, :filter

  def config
    context.config
  end

  def env
    context.env
  end

  def picker
    Hatchbox::ServerPicker.new(app: context.app)
  end

  def from_cluster
    @server = picker.pick(filter)
    @host = server["public_ip"].to_s
    @port = server["ssh_port"].to_s if Hatchbox.blank?(port)
    return unless Hatchbox.blank?(host)

    raise Hatchbox::Error, "#{server_label} has no public ip. set ssh_host:#{env} in #{config.path}"
  end
end

class Hatchbox::LogStream


  ENDED = ["completed", "failed", "aborted"].freeze

  def initialize(client:, app:, env:, log_id:)
    @client = client
    @app = app
    @env = env
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

  attr_reader :client, :app, :env, :log_id, :seen, :headers

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
    puts("pick it back up with: hatchbox -e #{env} logs #{log_id}".dim)
    false
  end
end

class Hatchbox::ProcessCatalog

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

    found = all.find { |row| self.class.label(row).downcase == wanted.to_s.downcase || row["id"].to_s == wanted.to_s }
    raise Hatchbox::Error, "no process called #{wanted}\n\n#{listing}" if found.nil?

    found
  end

  def table
    return "  none" if all.empty?

    width = all.map { |row| self.class.label(row).length }.max
    place = all.map { |row| self.class.where(row).length }.max
    all.map { |row| line(row: row, width: width, place: place) }.join("\n")
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

module Hatchbox::Options

  def parse_args(list:, name:, hint: nil)
    parser = OptionParser.new
    parser.on("-h", "--help") do
      puts(Hatchbox::USAGE)
      exit(0)
    end
    yield(parser) if block_given?
    parser.parse!(list)
    list
  rescue OptionParser::InvalidOption => e
    message = "unknown option for #{name}: #{e.args.join(" ")}"
    raise Hatchbox::Error, hint ? "#{message}. #{hint}" : message
  rescue OptionParser::MissingArgument => e
    raise Hatchbox::Error, "#{e.args.join(" ")} needs a value"
  rescue OptionParser::InvalidArgument => e
    raise Hatchbox::Error, "#{e.args.join(" ")} is not a value #{name} takes there"
  end

  def reject_extra(list, name:)
    return if list.empty?

    raise Hatchbox::Error, "#{name} takes no arguments, got #{list.join(" ")}"
  end
end

class Hatchbox::Command

  include Hatchbox::Options

  class << self

    def call(context:, args:)
      new(context: context, args: args).call
    end
  end

  def initialize(context:, args:)
    @context = context
    @args = args
  end

  private

  attr_reader :context, :args

  def config
    context.config
  end

  def client
    context.client
  end

  def app
    context.app
  end

  def env
    context.env
  end

  def app_id
    context.app_id
  end

  def follow(log_id)
    stream(log_id).follow ? 0 : 1
  end

  def show(log_id)
    stream(log_id).show ? 0 : 1
  end

  def stream(log_id)
    Hatchbox::LogStream.new(client: client, app: app, env: env, log_id: log_id)
  end

  def queue(path:, kind:)
    response = client.post(path)
    data = response.json || {}
    log_id = data["id"]
    raise Hatchbox::Error, "hatchbox accepted the #{kind} but returned no log id: #{response.body}" if Hatchbox.blank?(log_id)

    config.set(key: "last_#{kind}:#{env}", value: log_id)
    data
  end

  def print_json(data)
    puts(JSON.pretty_generate(data))
    0
  end

  def passthru
    cut = args.index("--")
    cut ? args[(cut + 1)..-1] : []
  end

  def parse(name:, hint: nil, &block)
    cut = args.index("--")
    parse_args(list: cut ? args[0, cut] : args.dup, name: name, hint: hint, &block)
  end
end

class Hatchbox::Deploy < Hatchbox::Command

  def call
    options = { watch: false }
    rest = parse(name: "deploy") do |parser|
      parser.on("--watch") { options[:watch] = true }
      parser.on("--no-follow") { options[:watch] = false }
      parser.on("--status") { options[:status] = true }
    end
    rest.each do |arg|
      raise Hatchbox::Error, "unknown option for deploy: #{arg}" unless arg == "status"

      options[:status] = true
    end
    return Hatchbox::Status.call(context: context, args: []) if options[:status]

    start(options)
  end

  private

  def start(options)
    data = queue(path: "/apps/#{app_id}/deploy", kind: "deploy")

    unless options[:watch]
      puts(JSON.pretty_generate(data))
      return 0
    end

    log_id = data["id"]
    puts("queued deploy to #{env.cyan}, log #{log_id.to_s.cyan}")
    puts
    follow(log_id)
  end
end

class Hatchbox::Status < Hatchbox::Command

  def call
    parse(name: "status")
    puts("#{env.cyan}, app #{app_id}")
    report_deploy
    puts

    log_id = config.get("last_deploy:#{env}")
    return show(log_id) unless Hatchbox.blank?(log_id)

    puts(no_log_help.dim)
    0
  end

  private

  def report_deploy
    sha = app.last_deploy_sha
    if sha.empty?
      puts("no deploy recorded on this app yet")
      return
    end

    line = "last deploy #{sha[0, 7].cyan}"
    line = "#{line} at #{app.last_deploy_at}" unless app.last_deploy_at.empty?
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
      "url to hatchbox logs"
    ].join("\n")
  end
end

class Hatchbox::PsCommand < Hatchbox::Command

  private

  def catalog
    @catalog ||= Hatchbox::ProcessCatalog.new(client: client, app_id: app_id)
  end

  def one(rest, name:)
    raise Hatchbox::Error, "#{name} needs a process name\n\n#{catalog.listing}" if rest.empty?
    raise Hatchbox::Error, "one process at a time, #{name} got #{rest.join(" ")}" if rest.length > 1

    catalog.find(rest.first)
  end

  def path_for(process, suffix = nil)
    base = "/apps/#{app_id}/processes/#{process["id"]}"
    suffix ? "#{base}/#{suffix}" : base
  end

  def label(process)
    Hatchbox::ProcessCatalog.label(process)
  end

  def settle(response, note, kind: nil)
    data = response.json
    id = log_id_in(data)
    unless id
      puts(note)
      return 0
    end

    config.set(key: "last_#{kind}:#{env}", value: id) if kind
    puts("#{note}, log #{id.to_s.cyan}")
    puts
    follow(id)
  end

  def log_id_in(data)
    return nil unless data.is_a?(Hash)
    return nil unless data.key?("state") || data.key?("child_logs") || data.key?("loggable_type")

    id = data["id"]
    Hatchbox.blank?(id) ? nil : id
  end
end

class Hatchbox::Ps < Hatchbox::PsCommand

  def call
    parse(name: "ps")
    rows = catalog.all
    if rows.empty?
      puts("no processes on #{env}")
      return 0
    end

    puts("processes on #{env.cyan}, app #{app_id}")
    puts
    puts(catalog.table)
    0
  end
end

class Hatchbox::PsRestart < Hatchbox::PsCommand

  def call
    rest = parse(name: "ps:restart")
    return whole_app if rest.empty?

    process = one(rest, name: "ps:restart")
    settle(client.post(path_for(process, "restart")), "queued restart of #{label(process).cyan} on #{env}", kind: "restart")
  end

  private

  def whole_app
    log_id = queue(path: "/apps/#{app_id}/restart", kind: "restart")["id"]
    puts("queued restart of every process on #{env.cyan}, log #{log_id.to_s.cyan}")
    puts

    follow(log_id)
  end
end

class Hatchbox::PsStart < Hatchbox::PsCommand

  def call
    process = one(parse(name: "ps:start"), name: "ps:start")
    settle(client.post(path_for(process, "activation")), "enabled #{label(process).cyan} on #{env}")
  end
end

class Hatchbox::PsStop < Hatchbox::PsCommand

  def call
    process = one(parse(name: "ps:stop"), name: "ps:stop")
    settle(client.delete(path_for(process, "activation")), "disabled #{label(process).cyan} on #{env}")
  end
end

class Hatchbox::Logs < Hatchbox::Command

  HINT = "logs --ps sidekiq --tail, and ssh's own flags after a --"

  def call
    options = { lines: 100, follow: false }
    rest = parse(name: "logs", hint: HINT) do |parser|
      parser.on("-p", "--ps NAME") { |value| options[:process] = value }
      parser.on("-d", "--dyno NAME") { |value| options[:process] = value }
      parser.on("-n", "--num LINES", Integer) { |value| options[:lines] = value }
      parser.on("-t", "--tail") { options[:follow] = true }
      parser.on("-f", "--follow") { options[:follow] = true }
      parser.on("-s", "--server NAME") { |value| options[:server] = value }
      parser.on("--since WHEN") { |value| options[:since] = value }
      parser.on("--units") { options[:units] = true }
    end
    raise Hatchbox::Error, "one process at a time. #{HINT}" if rest.length > 1

    options[:process] = rest.first if rest.any? && Hatchbox.blank?(options[:process])
    tail(options)
  end

  private

  def tail(options)
    process = options[:process] ? catalog.find(options[:process]) : nil
    target = Hatchbox::SshTarget.resolve(context: context, filter: options[:server])
    warn(heading(process: process, target: target).dim)
    Hatchbox.run(command_line(target: target, script: script(process: process, target: target, options: options)))
  end

  def catalog
    @catalog ||= Hatchbox::ProcessCatalog.new(client: client, app_id: app_id)
  end

  def script(process:, target:, options:)
    Hatchbox::Journal.new(
      app_name: target.app_name,
      process_name: process ? process["name"] : nil,
      lines: options[:lines],
      follow: options[:follow],
      since: options[:since],
      units_only: options[:units]
    ).script
  end

  def command_line(target:, script:)
    argv = ["ssh", "-p", target.port.to_s]
    argv.concat(passthru)
    argv << "-t" if $stdout.tty?
    argv << target.address
    argv << "bash -lc #{Shellwords.escape(script)}"
    argv
  end

  def heading(process:, target:)
    who = process ? Hatchbox::ProcessCatalog.label(process) : "every process"
    where = target.server_label || target.host
    "#{who} on #{where}, journal on the server, hatchbox stores none of this"
  end
end

class Hatchbox::Envs < Hatchbox::Command

  def call
    parse(name: "envs")
    puts("environments in #{config.path}")
    config.apps.each do |name, slug|
      current = name == env ? " (in use)".green : ""
      puts("  #{name}, app #{slug}#{current}")
    end
    0
  end
end

class Hatchbox::Vars < Hatchbox::Command

  USABLE = /\A[A-Z0-9_]+\z/.freeze
  HINT = "vars set NAME=VALUE, or vars unset NAME"

  def call
    rest = parse(name: "vars", hint: HINT)
    action = rest.first
    return explain if Hatchbox.blank?(action)
    return set(rest.drop(1)) if action == "set"
    return unset(rest.drop(1)) if ["unset", "rm"].include?(action)

    raise Hatchbox::Error, "no vars command called #{action}. #{HINT}"
  end

  private

  def set(pairs)
    raise Hatchbox::Error, "vars set takes one NAME=VALUE" unless pairs.length == 1

    vars = [pair_for(pairs.first)]
    client.put("/apps/#{app_id}/env_vars", body: { "env_vars" => vars })
    report(verb: "set", names: vars.map { |var| var["name"] })
  end

  def unset(names)
    raise Hatchbox::Error, "vars unset takes a name" if names.empty?

    wanted = names.map { |name| usable(name) }
    client.delete("/apps/#{app_id}/env_vars", body: { "env_vars" => wanted })
    report(verb: "unset", names: wanted)
  end

  def report(verb:, names:)
    puts("#{verb} #{names.join(", ").cyan} on #{env}")
    puts("hatchbox pushes that to the servers itself and hands back no log id, so there is nothing to follow".dim)
    0
  end

  def pair_for(text)
    name, separator, value = text.partition("=")
    raise Hatchbox::Error, "#{text} is not NAME=VALUE" if separator.empty?

    { "name" => usable(name), "value" => value }
  end

  def usable(name)
    cleaned = name.strip.upcase
    raise Hatchbox::Error, "#{name} is not a name hatchbox takes, which is letters, numbers and underscores" unless cleaned =~ USABLE

    cleaned
  end

  def explain
    puts([
      "hatchbox has no endpoint that reads env vars back, and it never returns a value,",
      "so there is nothing to list here. what is set is on the app's dashboard page.",
      "",
      "  hatchbox vars set FOO=bar",
      "  hatchbox vars unset FOO",
      "",
      "hatchbox uppercases the names, and a value you type here lands in your shell history."
    ].join("\n"))
    0
  end
end

Hatchbox::USAGE = <<~USAGE
  hatchbox, talks to the hatchbox api for the app you are standing in

    deploy                 queue a deploy and print the json hatchbox hands back
    deploy --watch         queue it and stream the log until it lands
    deploy status          last deployed sha, then stream the most recent deploy log
    status                 the same thing

    ps                     the processes on the app, what they run, where they run
    ps:restart             restart every process and stream it
    ps:restart sidekiq     restart one of them
    ps:stop sidekiq        turn a process off, leaving it defined
    ps:start sidekiq       turn it back on

    logs                   the last 100 journal lines from every process
    logs --ps sidekiq      just that one
    logs --ps sidekiq -t   follow it
    logs -n 500 --since "1 hour ago"
    logs --ps sidekiq --units   which systemd units it would read, and stop there

    vars set FOO=bar       set an env var on the app, then hatchbox pushes it to
                           the servers
    vars unset FOO         take env vars off the app

    envs                   the environments this app is configured for

    -e ENV, --env ENV      which environment to act on, anywhere in the command

  the app comes from the nearest .hatchbox, looked for in the working directory and
  then upward. an app is a bare line, written the way the dashboard url spells it,
  followed by the environment it is:

    13673-fpd:production
    20001-fpd-qa:qa
    default = production

  only the leading number is read by hatchbox, so the rest is there to tell you
  which app you are looking at.

  with one environment it is used automatically, otherwise default decides and -e
  beats it.

  the api token is a secret and stays out of the repo. it is read from
  HATCHBOX_API_TOKEN, then from ~/.hatchbox, which is the token file and is never
  read as an app config. it takes token:ENV or a plain token:

    token = your-api-token

  logs is the odd one out, because it does not use the api. hatchbox stores no
  runtime output and publishes no endpoint that serves any, and there is nothing
  under a process at all. so logs goes to the server over ssh, finds the systemd
  units whose names hold the app and the process, and runs journalctl on them.
  --units prints what it matched without reading anything, which is worth doing
  once if you have a process whose name is a common word. it reaches for sudo only
  when journalctl says the deploy user cannot read the journal, and it falls back
  to user units if there are no system ones.

  because it is ssh, logs needs a server, and --server names one when the cluster
  has several.

  a log is only reachable by its id and hatchbox publishes no way to list them, so
  the id of every deploy and restart started from here is written back to
  .hatchbox:

    last_deploy:production = 4212
    last_restart:production = 4213

  env vars are write only here. hatchbox publishes no endpoint that lists them and
  never returns a value, so vars can set and unset but not read, and what is on the
  app is on its dashboard page. names are uppercased for you, and hatchbox pushes the
  change to the servers itself without handing back a log id to follow. a value typed
  into vars set lands in your shell history like anything else on the command line.

  env
    HATCHBOX_API_TOKEN     overrides the token in ~/.hatchbox
    HATCHBOX_ENV           default environment, still beaten by -e
    HATCHBOX_API_BASE      defaults to https://hatchbox.io/api/v1
USAGE

class Hatchbox::Cli

  COMMANDS = {
    "deploy" => Hatchbox::Deploy,
    "status" => Hatchbox::Status,
    "ps" => Hatchbox::Ps,
    "ps:restart" => Hatchbox::PsRestart,
    "ps:start" => Hatchbox::PsStart,
    "ps:stop" => Hatchbox::PsStop,
    "restart" => Hatchbox::PsRestart,
    "logs" => Hatchbox::Logs,
    "vars" => Hatchbox::Vars,
    "envs" => Hatchbox::Envs
  }.freeze

  class << self

    def call(argv)
      new(argv).call
    end
  end

  def initialize(argv)
    @argv = argv
    @env_name = nil
    @help = false
  end

  def call
    rest = strip_env
    name = rest.first
    if help || Hatchbox.blank?(name) || name == "help"
      puts(Hatchbox::USAGE)
      return 0
    end

    command = COMMANDS[name]
    raise Hatchbox::Error, "no command called #{name}\n\n#{Hatchbox::USAGE}" unless command

    command.call(context: Hatchbox::Context.load(env_name), args: rest.drop(1))
  end

  private

  attr_reader :argv, :env_name, :help

  def strip_env
    cut = argv.index("--")
    head = cut ? argv[0, cut] : argv.dup
    tail = cut ? argv[cut..-1] : []
    scan(head) + tail
  end

  def scan(head)
    rest = []
    parser = OptionParser.new
    parser.on("-e", "--env ENV") { |value| @env_name = value }
    parser.on("-h", "--help") { @help = true }
    parser.on("--version") { rest << "--version" }
    until head.empty?
      begin
        parser.order!(head) { |arg| rest << arg }
      rescue OptionParser::InvalidOption => e
        rest.concat(e.args)
      rescue OptionParser::MissingArgument
        raise Hatchbox::Error, "--env needs an environment"
      end
    end
    rest
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    exit(Hatchbox::Cli.call(ARGV))
  rescue Hatchbox::Error => e
    warn(e.message.red)
    exit(1)
  rescue Errno::EPIPE
    exit(0)
  end
end
