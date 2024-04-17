require 'puppeteer-ruby'
require 'nokogiri'

module YoutubeSearchCrawler
  def self.search_video(query, title = false)
    video_url = nil
    music_title = nil
    cached_result = Rails.cache.read("#{query}")
    return cached_result if cached_result

    Puppeteer.launch(headless: true) do |browser|
      page = browser.new_page
      page.goto("https://www.youtube.com/results?search_query=#{format_query(query)}")
      page.screenshot(path: "tmp/screenshot.png")
      first_video = page.query_selector("ytd-video-renderer ytd-thumbnail #thumbnail")
      video_url = first_video.evaluate('(element) => element.href')
      if title
        music_title = page.query_selector('ytd-video-renderer #meta #title-wrapper #video-title yt-formatted-string').evaluate('(element) => element.textContent')
      end
    end

    cached_data = {
      video_id: get_video_id(video_url),
      title: music_title
    }

    Rails.cache.write("#{query}", cached_data)
    {video_id: cached_data[:video_id], title: cached_data[:title]}
  end

  def self.search_video_by_playlist(tracks, user_id, server_id)
    Puppeteer.launch(headless: true) do |browser|
      page = browser.new_page
      tracks.each do |track|
        cached_result = Rails.cache.read("#{track[:name]} - #{track[:artist]}")
        if cached_result
          enqueue_song(cached_result[:video_id], cached_result[:title], user_id, server_id)
          next
        end
        page.goto("https://www.youtube.com/results?search_query=#{format_query("#{track[:name]} #{track[:artist]}")}")
        first_video = page.query_selector("ytd-video-renderer ytd-thumbnail #thumbnail")
        page.screenshot(path: "tmp/screenshotee.png")
        video_url = first_video.evaluate('(element) => element.href')
        title = page.query_selector('ytd-video-renderer #meta #title-wrapper #video-title yt-formatted-string').evaluate('(element) => element.textContent')
        cached_data = {
          video_id: get_video_id(video_url),
          title: title
        }
        Rails.cache.write("#{track[:name]} - #{track[:artist]}", cached_data)
        enqueue_song(cached_data[:video_id], cached_data[:title], user_id, server_id)
      end
      page.close
    end
    []
  end

  def self.get_video_title(video_url)
    Puppeteer.launch(headless: true) do |browser|
      page = browser.new_page
      page.goto(video_url)
      page.wait_for_selector('#title h1 yt-formatted-string')
      h1_text_content = page.evaluate('(selector) => document.querySelector(selector).textContent', '#title h1 yt-formatted-string')
      h1_text_content
    end
  end

  private
  def self.format_query(query)
    query.gsub(' ', '+' )
  end

  def self.get_video_id(video_url)
    parts = video_url.split(/[?&]/)
    video_id_part = parts.find { |part| part.start_with?('v=') }
    if video_id_part
      video_id_part.split('=')[1]
    end
  end

  def self.enqueue_song(video_id, video_title, user_id, server_id)
    user_queue = Rails.cache.read("#{server_id + user_id}_song_queue")
    user_queue << {id: video_id, title: video_title}
    Rails.cache.write("#{server_id + user_id}_song_queue", user_queue)
  end
end
