require "discordrb"
require "rspotify"
require_relative "patches/discordrb_dave_transition_fix"
require_relative "mae_music"
require_relative "mae_default"
require_relative "seer_webhook_server"

module DiscordBot
  class Bot
    attr_reader :discordrb_bot

    def initialize
      setup_apis
      @bot = Discordrb::Commands::CommandBot.new(
        token: ENV.fetch("DISCORD_BOT_TOKEN"),
        client_id: ENV.fetch("DISCORD_BOT_CLIENT_ID"),
        prefix: "$"
      )
      @discordrb_bot = @bot
      DiscordBot::MaeDefault.commands(@bot)
      DiscordBot::MaeMusic.commands(@bot)
      start_seer_webhook_server
    end

    def run
      @bot.run
    end

    private

    def setup_apis
      RSpotify.authenticate(ENV.fetch("SPOTIFY_CLIENT_ID"), ENV.fetch("SPOTIFY_CLIENT_SECRET"))
    end

    def start_seer_webhook_server
      return if ENV["SEER_WEBHOOK_SECRET"].nil? || ENV["SEER_WEBHOOK_SECRET"].empty?

      Thread.new { DiscordBot::SeerWebhookServer.new(@bot).start }
    end
  end
end
