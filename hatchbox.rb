#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "optparse"

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

class Hatchbox::Context

  class << self

    def load(env_name)
      new(env_name).load
    end
  end

  attr_reader :env, :app_id, :token

  def initialize(env_name)
    @env = env_name
  end

  def load
    @path = File.join(Dir.pwd, ".hatchbox")
    raise Hatchbox::Error, "no .hatchbox in #{Dir.pwd}. see hatchbox --help for the format" unless File.file?(@path)

    apps = read_apps
    @env = apps.keys.first if Hatchbox.blank?(env) && apps.length == 1
    raise Hatchbox::Error, "#{@path} has more than one environment, so pick one with -e" if Hatchbox.blank?(env)

    @app_id = apps[env]
    raise Hatchbox::Error, "no app is listed for #{env} in #{@path}" if Hatchbox.blank?(app_id)

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

  def read_apps
    File.readlines(@path).each_with_object({}) do |line, found|
      app, _colon, name = line.strip.rpartition(":")
      found[name] = app unless app.empty? || line.include?("=")
    end
  end

  def read_token
    from_env = ENV["HATCHBOX_API_TOKEN"]
    return from_env unless Hatchbox.blank?(from_env)
    return nil unless File.file?(Hatchbox::GLOBAL_CONFIG)

    line = File.readlines(Hatchbox::GLOBAL_CONFIG).find { |text| text.strip.start_with?("token") && text.include?("=") }
    line ? line.split("=", 2).last.strip : nil
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

  def emit(key:, text:)
    old = seen[key].to_s
    if old.empty?
      print(text) unless text.empty?
    elsif text.length > old.length && text.start_with?(old)
      print(text[old.length + 1..-1])
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

  def stream(log_id)
    Hatchbox::LogStream.new(client: client, app: app, env: env, log_id: log_id)
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
    end
    reject_extra(rest, name: "deploy")
    start(options)
  end

  private

  def start(options)
    response = client.post("/apps/#{app_id}/deploy")
    data = response.json || {}
    return print_json(data) unless options[:follow]

    log_id = data["id"]
    raise Hatchbox::Error, "hatchbox accepted the deploy but returned no log id: #{response.body}" if Hatchbox.blank?(log_id)

    puts("queued deploy to #{env.cyan}, log #{log_id.to_s.cyan}")
    puts
    follow(log_id)
  end
end

Hatchbox::USAGE = <<~USAGE
  hatchbox, talks to the hatchbox api for the app you are standing in

    deploy                 queue a deploy and stream it until it lands
    deploy --no-follow     queue it and print the json hatchbox hands back

    -e ENV, --env ENV      which environment to act on, anywhere in the command

  the app comes from .hatchbox in the working directory. an app is a bare line,
  written the way the dashboard url spells it, followed by the environment it is:

    13673-fpd:production
    20001-fpd-qa:qa

  with one environment it is used automatically, otherwise -e picks one.

  the api token is read from HATCHBOX_API_TOKEN, then from ~/.hatchbox:

    token = your-api-token

  env
    HATCHBOX_API_TOKEN     overrides the token in ~/.hatchbox
    HATCHBOX_API_BASE      defaults to https://hatchbox.io/api/v1
USAGE

class Hatchbox::Cli

  COMMANDS = {
    "deploy" => Hatchbox::Deploy
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
