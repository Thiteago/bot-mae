source "https://rubygems.org"

ruby "3.4.1"

gem "discordrb", github: "coderobe/discordrb-dave", ref: "dce74da589e786552f88886ba77754b9ebc53446"
gem "dotenv"
gem "opus-ruby"
gem "rspotify"
gem "sidekiq", "~> 7.3"
gem "redis", "~> 5.3"
gem "connection_pool", "~> 2.4" # sidekiq 7.3 is incompatible with connection_pool 3.x

group :development, :test do
  gem "debug", platforms: %i[mri windows]
end
