require 'discordrb'
require 'rspotify'
require_relative 'mae_music'
require_relative 'mae_talk'
require_relative 'mae_default'

module DiscordBot
  class Bot
    OUTPUT_FOLDER = "tmp/songs"
    $running_threads = []

    def initialize
      setup_apis

      bot = Discordrb::Commands::CommandBot.new token: ENV.fetch('DISCORD_BOT_TOKEN'), client_id: ENV.fetch('DISCORD_BOT_CLIENT_ID'), prefix: '$'
      DiscordBot::MaeDefault.commands(bot)
      DiscordBot::MaeMusic.commands(bot)
      DiscordBot::MaeTalk.commands(bot)
      bot_thread = Thread.new { bot.run }
    end

    private
    def setup_apis
      RSpotify.authenticate(ENV.fetch('SPOTIFY_CLIENT_ID'), ENV.fetch('SPOTIFY_CLIENT_SECRET'))
    end
  end
end

DiscordBot::Bot.new
