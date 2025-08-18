redis_config = {
  url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
}

# Configure SSL settings for Heroku Redis in production
if ENV["REDIS_URL"]&.start_with?("rediss://")
  redis_config[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
end

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
