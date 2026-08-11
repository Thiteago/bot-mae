require "redis"
require "json"

module DiscordBot
  module RedisCache
    def self.client
      @client ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
    end

    def self.read(key)
      value = client.get(key)
      value.nil? ? nil : JSON.parse(value, symbolize_names: true)
    end

    def self.write(key, value)
      client.set(key, value.to_json)
      value
    end

    def self.fetch(key)
      existing = read(key)
      return existing unless existing.nil?

      write(key, yield)
    end
  end
end
