require "discordrb"
require "rspotify"
require_relative "patches/discordrb_dave_transition_fix"
require_relative "mae_music"
require_relative "mae_default"

module DiscordBot
  class Bot
    def initialize
      setup_apis
      @bot = Discordrb::Commands::CommandBot.new(
        token: ENV.fetch("DISCORD_BOT_TOKEN"),
        client_id: ENV.fetch("DISCORD_BOT_CLIENT_ID"),
        prefix: "$"
      )
      DiscordBot::MaeDefault.commands(@bot)
      DiscordBot::MaeMusic.commands(@bot)
    end

    def run
      @bot.run
    end

    private

    def setup_apis
      RSpotify.authenticate(ENV.fetch("SPOTIFY_CLIENT_ID"), ENV.fetch("SPOTIFY_CLIENT_SECRET"))
    end
  end
end
