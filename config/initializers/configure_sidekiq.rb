Sidekiq.configure_server do |config|
  config.redis = { host: 'localhost', port: 6379 }
end

Sidekiq.configure_client do |config|
  config.redis = { host: 'localhost', port: 6379 }
end

Sidekiq.configure_server do |config|

  if File.exist?(schedule_file)
    Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
  end
end
