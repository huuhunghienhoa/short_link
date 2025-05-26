shortlink_log_path = Rails.root.join("log/shortlink_#{Rails.env}.log")

SHORTLINK_LOGGER = Logger.new(
  shortlink_log_path,
  5,                      # Keep 5 files log
  10 * 1024 * 1024        # Each log file: 10MB
)

SHORTLINK_LOGGER.level = if Rails.env.production?
  Logger::INFO
else
  Logger::DEBUG
end

SHORTLINK_LOGGER.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime}] #{severity}: #{msg}\n"
end
