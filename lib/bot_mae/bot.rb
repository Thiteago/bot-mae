require "discordrb"
require_relative "mae_default"
require_relative "seer_webhook_server"

module DiscordBot
  class Bot
    attr_reader :discordrb_bot

    def initialize
      @bot = Discordrb::Commands::CommandBot.new(
        token: ENV.fetch("DISCORD_BOT_TOKEN"),
        client_id: ENV.fetch("DISCORD_BOT_CLIENT_ID"),
        prefix: "$"
      )
      @discordrb_bot = @bot
      DiscordBot::MaeDefault.commands(@bot)
      start_seer_webhook_server
    end

    def run
      @bot.run
    end

    private

    def start_seer_webhook_server
      return if ENV["SEER_WEBHOOK_SECRET"].nil? || ENV["SEER_WEBHOOK_SECRET"].empty?

      Thread.new { DiscordBot::SeerWebhookServer.new(@bot).start }
    end
  end
end
