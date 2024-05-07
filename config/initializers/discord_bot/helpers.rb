require_relative 'youtube_search_crawler'
YOUTUBE_PLAYLIST = /^(http(s)?:\/\/)?((w){3}.)?youtu(be|.be)?(\.com)?\/playlist\?list=.+/i
YOUTUBE_TRACK = /^(http(s)?:\/\/)?((w){3}.)?youtu(be|.be)?(\.com)?\/watch\?v=.+/i
SPOTIFY_PLAYLIST = /^(http(s)?:\/\/)?((w){3}.)?open.spotify.com\/playlist\/.+/i
SPOTIFY_TRACK = /^(http(s)?:\/\/)?((w){3}.)?open.spotify.com\/track\/.+/i
SPOTIFY_ALBUM = /^(http(s)?:\/\/)?((w){3}.)?open.spotify.com\/album\/.+/i

module DiscordBot
  class Helpers
    attr_accessor :details

    def initialize(user_id:, server_id:, voice_channel_id:, requested_song:, user_queue:, event:, bot:)
      @details = {
        user_id: user_id,
        server_id: server_id,
        voice_channel_id: voice_channel_id,
        requested_song: requested_song,
        event: event,
        platform: nil,
        type: nil,
        user_queue: user_queue,
        bot: bot
      }

      @youtube_patterns = [YOUTUBE_PLAYLIST, YOUTUBE_TRACK]
      @spotify_patterns = [SPOTIFY_PLAYLIST, SPOTIFY_TRACK, SPOTIFY_ALBUM]
    end

    def recursive_queue_play
      @details[:bot].voice_connect(@details[:voice_channel_id]) if !@details[:bot].voice(@details[:server_id])
      user_queue = Rails.cache.read(@details[:user_queue])
      if !user_queue.empty? && !@details[:bot].voice(@details[:server_id]).isplaying?
        song = user_queue[0]
        youtube_dl_command = "yt-dlp -q -o - #{is_youtube_link?(song[:id]) ? song : "https://www.youtube.com/watch?v=#{song[:id]}"} | ffmpeg -i pipe:0 -f s16le -ar 48000 -ac 2 pipe:1 2>/dev/null"
        pipe = IO.popen(youtube_dl_command, 'r')
        @details[:event].respond "Tocando `#{song[:title]}`"
        @details[:bot].voice(@details[:server_id]).play(pipe)
        shift_queue if !Rails.cache.read("stop_playing_#{@details[:server_id]}_#{@details[:voice_channel_id]}")
      end
      return Rails.cache.write("stop_playing_#{@details[:server_id]}_#{@details[:voice_channel_id]}", false) if has_been_stop_requested?
      return recursive_queue_play if !user_queue.empty?
      return
    end

    def has_been_stop_requested?
      Rails.cache.read("stop_playing_#{@details[:server_id]}_#{@details[:voice_channel_id]}")
    end

    def is_youtube_link?(song_id = nil)
      @youtube_patterns.each do |pattern|
        if song_id != nil
          return true if song_id.match(pattern)
        else
          break
        end
        if @details[:requested_song].match(pattern)
          @details[:platform] = 'youtube'
          @details[:type] = pattern.to_s.split('_')[1]
          return true
        end
      end
      return false
    end

    def shift_queue
      user_queue = Rails.cache.read(@details[:user_queue])
      user_queue.shift
      Rails.cache.write(@details[:user_queue], user_queue)
    end

    def self.clean_queue(event)
      Rails.cache.write("#{event.server.id}_#{event.author.voice_channel.id}_server_queue", [])
    end

    def is_spotify_link?
      @spotify_patterns.each do |pattern|
        if @details[:requested_song].match(pattern)
          @details[:platform] = 'spotify'
          @details[:type] = pattern.to_s.split('_')[1]
          return true
        end
      end
      return false
    end

    def search_song
      video = nil
      if @details[:platform] == 'not_identified'
        video = DiscordBot::YoutubeSearchCrawler.search_video(@details[:requested_song], true)
        enqueue_song(video[:video_id], video[:title]) if video
      elsif @details[:platform] == 'youtube'
        if(@details[:requested_song].include?('youtu.be'))
          song_id = @details[:requested_song].split('be/')[1]
        else
          song_id = @details[:requested_song].split('v=')[1]
        end
        video_title = DiscordBot::YoutubeSearchCrawler.get_video_title(@details[:requested_song])
        enqueue_song(song_id, video_title)
      elsif @details[:platform] == 'spotify'
        if @details[:type] == 'playlist'
          playlist_id = @details[:requested_song].split('playlist/')[1].split('?')[0]
          playlist = RSpotify::Playlist.find_by_id(playlist_id)

          playlist_length = playlist.total
          limit = 100
          offset = 0
          if Rails.cache.read(@details[:user_queue]).empty?
            video = DiscordBot::YoutubeSearchCrawler.search_video(playlist.tracks[0].name + " " + playlist.tracks[0].artists[0].name, true)
            enqueue_song(video[:video_id], video[:title]) if video
            playlist.tracks.shift
          end

          while offset < playlist_length
            remaining = playlist_length - offset
            current_limit = [limit, remaining].min

            tracks = playlist.tracks(limit: current_limit, offset: offset)
            tracks = tracks.map { |track| { name: track.name, artist: track.artists[0].name } }
            SearchVideoByPlaylistJob.perform_now(tracks, user_id, server_id)

            offset += current_limit
          end
        elsif @details[:type] == 'track'
          track = RSpotify::Track.find(@details[:requested_song].split('track/')[1])
          video = DiscordBot::YoutubeSearchCrawler.search_video(track.name + " " + track.artists.first.name, true)
          enqueue_song(video[:video_id],video[:title]) if video
        else
          album = RSpotify::Album.find(@details[:requested_song].split('album/')[1])
          album.tracks.each do |track|
            video = DiscordBot::YoutubeSearchCrawler.search_video(track.name + " " + track.artists.first.name, true)
            enqueue_song(video[:video_id], video[:title]) if video
          end
        end
      end
      return video
    end

    def find_songs
      original_queue_size = Rails.cache.read(@details[:user_queue]).size
      if is_youtube_link?
        result = search_song
        if !result.nil?
          if Rails.cache.read(@details[:user_queue]).size > original_queue_size && original_queue_size > 0
            @details[:event].respond "Coloquei `#{result[:title]}` na lista patrão!"
          end
        end
      elsif is_spotify_link?
        result = search_song
        if !result.nil?
          if Rails.cache.read(@details[:user_queue]).size > original_queue_size && original_queue_size > 0
            @details[:event].respond "Coloquei `#{result[:title]}` na lista patrão!"
          end
        end
      else
        @details[:platform] = 'not_identified'
        @details[:requested_song].gsub!('$toca', "music")
        result = search_song
        if !result.nil?
          if Rails.cache.read(@details[:user_queue]).size > original_queue_size && original_queue_size > 0
            @details[:event].respond "Coloquei `#{result[:title]}` na lista patrão!"
          end
        end
      end
    end

    def enqueue_song(video_id, video_title)
      queue = Rails.cache.read(@details[:user_queue])
      queue << {id: video_id, title: video_title}
      Rails.cache.write(@details[:user_queue], queue)
    end

    def create_queue_embed(user_queue, requested_page=1)
      embed = Discordrb::Webhooks::Embed.new
      embed.title = "Fila de músicas - Página #{requested_page} - #{user_queue.size} músicas"
      embed.description = ""
      page = requested_page.to_i
      page = 1 if page == 0
      start_index = (page - 1) * 10
      end_index = start_index + 10
      user_queue[start_index..end_index].each_with_index do |song, index|
        link = is_youtube_link?(song[:id]) ? song : "https://www.youtube.com/watch?v=#{song[:id]}"
        embed.description += "#{start_index + index + 1}. [#{song[:title]}](#{link})\n"
      end
      embed.color = 0xeb237d
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Página #{requested_page} de #{(user_queue.size / 10.0).ceil}")
      embed
    end
  end
end
