#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "optparse"
require "pathname"

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

  class Error < StandardError; end

  class << self

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end

class Hatchbox::Http

  METHODS = {
    "GET" => Net::HTTP::Get,
    "POST" => Net::HTTP::Post
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

  def parse(name:, hint: nil, &block)
    parse_args(list: args.dup, name: name, hint: hint, &block)
  end
end

class Hatchbox::Deploy < Hatchbox::Command

  def call
    options = { follow: true }
    rest = parse(name: "deploy") do |parser|
      parser.on("--no-follow") { options[:follow] = false }
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
    return print_json(data) unless options[:follow]

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

Hatchbox::USAGE = <<~USAGE
  hatchbox, talks to the hatchbox api for the app you are standing in

    deploy                 queue a deploy and stream it until it lands
    deploy --no-follow     queue it and print the json hatchbox hands back
    deploy status          last deployed sha, then stream the most recent deploy log
    status                 the same thing

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

  a log is only reachable by its id and hatchbox publishes no way to list them, so
  the id of every deploy started from here is written back to .hatchbox:

    last_deploy:production = 4212

  env
    HATCHBOX_API_TOKEN     overrides the token in ~/.hatchbox
    HATCHBOX_ENV           default environment, still beaten by -e
    HATCHBOX_API_BASE      defaults to https://hatchbox.io/api/v1
USAGE

class Hatchbox::Cli

  COMMANDS = {
    "deploy" => Hatchbox::Deploy,
    "status" => Hatchbox::Status,
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
    scan(argv.dup)
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
  end
end
