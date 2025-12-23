require "active_support/core_ext/integer/time"

Rails.application.configure do
  # In the development environment your application's code is reloaded on
  # any change. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false
  config.eager_load = false

  config.consider_all_requests_local = true

  config.server_timing = true
end


