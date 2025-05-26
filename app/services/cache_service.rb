class CacheService
  URL_NAMESPACE = "short_link:by_url".freeze
  CODE_NAMESPACE = "short_link:by_code".freeze
  TTL = 5.minutes

  def initialize
    @cache_redis = CacheRedis
  end

  def fetch_short_code_by_url original_url
    fetch(URL_NAMESPACE, Digest::SHA256.hexdigest(original_url))
  end

  def store_short_code_by_url original_url, short_code
    store(URL_NAMESPACE, Digest::SHA256.hexdigest(original_url), short_code)
  end

  def fetch_original_url short_code
    fetch(CODE_NAMESPACE, short_code)
  end

  def store_original_url short_code, original_url
    store(CODE_NAMESPACE, short_code, original_url)
  end

  private

  attr_reader :cache_redis

  def fetch namespace, key
    cache_redis.with{|conn| conn.get(cache_key(namespace, key))}
  end

  def store namespace, key, value
    cache_redis.with{|conn| conn.set(cache_key(namespace, key), value, ex: TTL)}
  end

  def cache_key namespace, key
    "#{namespace}:#{key}"
  end
end
