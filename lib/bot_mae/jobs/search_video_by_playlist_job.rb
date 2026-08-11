require 'sidekiq'
require_relative '../youtube_search_crawler'

class SearchVideoByPlaylistJob
  include Sidekiq::Job
  sidekiq_options queue: :search

  def perform(tracks, user_id, server_id, voice_channel_id)
    DiscordBot::YoutubeSearchCrawler.search_video_by_playlist(tracks, user_id, server_id, voice_channel_id)
  end
end
