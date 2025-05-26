require 'connection_pool'

RedisConfig = {
  timeout: 5
}.freeze

# When scale, use mutil cluster
CacheRedis = ConnectionPool.new(size: 5, timeout: 5) do
  Redis.new(url: ENV.fetch("REDIS_CACHE_URL") { "redis://redis:6379/1" }, **RedisConfig)
end

RateLimitRedis = ConnectionPool.new(size: 5, timeout: 5) do
  Redis.new(url: ENV.fetch("REDIS_RATE_LIMIT_URL") { "redis://redis:6379/2" }, **RedisConfig)
end

LockRedis = ConnectionPool.new(size: 5, timeout: 5) do
  Redis.new(url: ENV.fetch("REDIS_LOCK_URL") { "redis://redis:6379/3" }, **RedisConfig)
end
