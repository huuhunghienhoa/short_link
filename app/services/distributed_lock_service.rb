require "redis"

class DistributedLockService
  RETRY_COUNT = 10
  RETRY_DELAY = 500
  TTL = 10

  def initialize
    @redis = LockRedis
    @lock_key = "lock:short_link"
  end

  def with_lock
    lock_value = SecureRandom.uuid

    RETRY_COUNT.times do
      if acquire_lock(lock_value)
        begin
          yield
        ensure
          release_lock_if_owner(lock_value)
        end
        return
      else
        sleep(RETRY_DELAY / 1000.0)
      end
    end

    raise LockAcquisitionFailedError
  end

  private

  attr_reader :lock_key, :redis

  def acquire_lock lock_value
    with_redis{|conn| conn.set(lock_key, lock_value, nx: true, ex: TTL)}
  end

  def release_lock_if_owner lock_value
    current_value = with_redis{|conn| conn.get(lock_key)}
    with_redis{|conn| conn.del(lock_key)} if current_value == lock_value
  end

  def with_redis &block
    @redis.with(&block)
  end
end
