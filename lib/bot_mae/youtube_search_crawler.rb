require 'net/http'
require 'json'

module DiscordBot
  class YoutubeSearchCrawler
    YOUTUBE_API_BASE = 'https://www.googleapis.com/youtube/v3'

    def self.search_video(query)
      cached_result = DiscordBot::RedisCache.read("#{query}")
      return cached_result if cached_result

      item = api_get('search', part: 'snippet', type: 'video', maxResults: 1, q: query)['items']&.first
      return nil unless item

      cached_data = {
        video_id: item.dig('id', 'videoId'),
        title: item.dig('snippet', 'title')
      }
      DiscordBot::RedisCache.write("#{query}", cached_data)
      cached_data
    end

    def self.search_video_by_playlist(tracks, user_id, server_id, voice_channel_id)
      tracks = tracks.map { |track| track.transform_keys(&:to_sym) }
      queue_key = "#{server_id}_#{voice_channel_id}_server_queue"

      tracks.each do |track|
        cache_key = "#{track[:name]} - #{track[:artist]}"
        cached_result = DiscordBot::RedisCache.read(cache_key)
        result = cached_result || search_video("#{track[:name]} #{track[:artist]}")
        next unless result

        enqueue_song(queue_key, result[:video_id], result[:title])
      end
      []
    end

    def self.get_video_title(video_url)
      video_id = get_video_id(video_url)
      item = api_get('videos', part: 'snippet', id: video_id)['items']&.first
      item&.dig('snippet', 'title')
    end

    private

    def self.api_get(resource, params)
      uri = URI("#{YOUTUBE_API_BASE}/#{resource}")
      uri.query = URI.encode_www_form(params.merge(key: ENV.fetch('YOUTUBE_API_KEY')))
      JSON.parse(Net::HTTP.get(uri))
    end

    def self.get_video_id(video_url)
      parts = video_url.split(/[?&]/)
      video_id_part = parts.find { |part| part.start_with?('v=') }
      video_id_part&.split('=')&.last
    end

    def self.enqueue_song(queue_key, video_id, video_title)
      user_queue = DiscordBot::RedisCache.read(queue_key) || []
      user_queue << { id: video_id, title: video_title }
      DiscordBot::RedisCache.write(queue_key, user_queue)
    end
  end
end
