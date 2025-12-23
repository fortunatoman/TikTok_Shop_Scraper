require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module TikTokShopAnalytics
  class Application < Rails::Application
    config.load_defaults 7.0
    config.api_only = true
    config.time_zone = 'UTC'
    config.active_record.default_timezone = :utc
  end
end

