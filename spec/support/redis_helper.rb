module RedisHelper
  def redis
    @redis ||= Redis.new(url: ENV["REDIS_CACHE_URL"] || "redis://localhost:6379/1")
  end

  def clear_redis
    redis.flushdb
  end
end
