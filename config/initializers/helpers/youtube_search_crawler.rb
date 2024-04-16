require 'puppeteer-ruby'

module YoutubeSearchCrawler
  def self.search_video(query, title = false)
    browser = Puppeteer.launch(headless: true)
    page = browser.new_page
    page.goto("https://www.youtube.com/results?search_query=#{format_query(query)}")
    sleep 3
    page.screenshot(path: "tmp/screenshot.png")
    first_video = page.query_selector("ytd-video-renderer ytd-thumbnail #thumbnail")
    first_video.click
    sleep 3
    video_url = page.url
    if title
      page.wait_for_selector('#title h1 yt-formatted-string')
      title = page.evaluate('(selector) => document.querySelector(selector).textContent', '#title h1 yt-formatted-string')
    end
    browser.close
    {video_id: get_video_id(video_url), title: title}
  end

  def self.search_video_by_playlist(tracks, user_id, server_id)
    tracks_info = []
    browser = Puppeteer.launch(headless: true)
    page = browser.new_page
    tracks.each do |track|
      page.goto("https://www.youtube.com/results?search_query=#{format_query("#{track[:name]} #{track[:artist]}")}")
      sleep 3
      first_video = page.query_selector("ytd-video-renderer ytd-thumbnail #thumbnail")
      page.screenshot(path: "tmp/screenshotee.png")
      first_video.click
      sleep 3
      video_url = page.url
      page.wait_for_selector('#title h1 yt-formatted-string')
      title = page.evaluate('(selector) => document.querySelector(selector).textContent', '#title h1 yt-formatted-string')
      enqueue_song(get_video_id(video_url), title, user_id, server_id)
    end
    browser.close
    tracks_info
  end

  def self.get_video_title(video_url)
    browser = Puppeteer.launch(headless: true)
    page = browser.new_page
    page.goto(video_url)
    sleep 3
    page.wait_for_selector('#title h1 yt-formatted-string')
    h1_text_content = page.evaluate('(selector) => document.querySelector(selector).textContent', '#title h1 yt-formatted-string')
    browser.close
    h1_text_content
  end

  private
  def self.format_query(query)
    query.gsub(' ', '+' )
  end

  def self.get_video_id(video_url)
    video_url.split('v=')[1]
  end

  def self.enqueue_song(video_id, video_title, user_id, server_id)
    user_queue = Rails.cache.read("#{server_id + user_id}_song_queue")
    user_queue << {id: video_id, title: video_title}
    Rails.cache.write("#{server_id + user_id}_song_queue", user_queue)
  end
end
