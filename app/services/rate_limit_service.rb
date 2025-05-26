class RateLimitService
  LIMIT_PER_USER_IP = 50 # requests
  EXPIRED_TIME = 60 # seconds

  def initialize ip, action
    @ip = ip
    @action = action
  end

  def check!
    key = "rate_limit:#{action}:#{ip}"
    count = RateLimitRedis.with{|conn| conn.incr(key)}
    RateLimitRedis.with{|conn| conn.expire(key, EXPIRED_TIME)} if count == 1
    raise RateLimitExceededError if count > LIMIT_PER_USER_IP
  end

  private

  attr_reader :ip, :action
end
