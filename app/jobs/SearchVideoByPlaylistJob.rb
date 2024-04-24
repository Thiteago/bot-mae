class SearchVideoByPlaylistJob < ApplicationJob
  queue_as :search

  def perform(tracks, user_id, server_id)
    DiscordBot::YoutubeSearchCrawler.search_video_by_playlist(tracks, user_id, server_id)
  end
end
