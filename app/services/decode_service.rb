class DecodeService
  def initialize short_code, ip
    @short_code = short_code
    @ip = ip
  end

  def call
    RateLimitService.new(ip, "decode").check!

    cached_url = CacheService.new.fetch_original_url(short_code)
    return cached_url if cached_url

    url_mapping = ShortUrl.find_by short_code: short_code
    raise ActiveRecord::RecordNotFound unless url_mapping

    CacheService.new.store_original_url(short_code, url_mapping.original_url)
    url_mapping.original_url
  end

  private

  attr_reader :short_code, :ip
end
