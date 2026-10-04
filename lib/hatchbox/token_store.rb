# frozen_string_literal: true

module Hatchbox
  class TokenStore
    def initialize(prompt: Hatchbox::Prompt.new)
      @prompt = prompt
      @global = Hatchbox::Config.new(Hatchbox::GLOBAL_CONFIG)
      @file = Hatchbox::ConfigFile.new(Hatchbox::GLOBAL_CONFIG)
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
      return path.to_s unless Hatchbox.blank?(global.get("token"))

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
      kept = file.lines.reject { |line| Hatchbox::ConfigLine.key(line) == "token" }
      File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |handle|
        (kept + ["token = #{token}"]).each { |line| handle.puts(line) }
      end
      File.chmod(0o600, path)
    end

    def forget
      found = file.lines.select { |line| token_key?(Hatchbox::ConfigLine.key(line)) }
      return 0 if found.empty?

      kept = file.lines.reject { |line| token_key?(Hatchbox::ConfigLine.key(line)) }
      File.open(path, File::WRONLY | File::TRUNC, 0o600) { |handle| kept.each { |line| handle.puts(line) } }
      found.length
    end

    private

    attr_reader :prompt, :global, :file

    def token_key?(key)
      key == "token" || key.to_s.start_with?("token:")
    end
  end
end
