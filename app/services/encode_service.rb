class EncodeService
  MAX_RETRIES = 5

  def initialize original_url, ip
    @original_url = original_url
    @ip = ip
  end

  def call
    RateLimitService.new(@ip, "encode").check!

    cached_short_code = CacheService.new.fetch_short_code_by_url(original_url)
    return cached_short_code if cached_short_code.present?

    short_code = nil
    retries = 0
    DistributedLockService.new.with_lock do
      begin
        short_code = generate_short_code
        ShortUrl.create!(original_url: original_url, short_code: short_code)
      rescue ActiveRecord::RecordNotUnique
        retries += 1
        retry if retries < MAX_RETRIES
        raise ShortCodeCreationExceededError
      end
      CacheService.new.store_short_code_by_url(original_url, short_code)
      CacheService.new.store_original_url(short_code, original_url)
    end
    short_code
  end

  private

  attr_reader :original_url, :ip

  def generate_short_code
    SecureRandom.alphanumeric ENV.fetch("SHORT_CODE_LENGTH", 8).to_i
  end
end
