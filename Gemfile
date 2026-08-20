source "https://rubygems.org"

ruby "3.4.1"

gem "discordrb", "~> 3.8"
gem "dotenv"
gem "webrick", "~> 1.8" # não é mais default gem no Ruby 3.4+, usado pro servidor de webhooks do Seerr

group :development, :test do
  gem "debug", platforms: %i[mri windows]
end
