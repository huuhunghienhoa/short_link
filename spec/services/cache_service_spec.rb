require "rails_helper"

RSpec.describe CacheService do
  let(:short_code){"Acbhf7H9"}
  let(:original_url){"https://google.com"}

  before{clear_redis}

  describe ".store_original_url and .fetch_short_code" do
    it "stores and retrieves a value from cache" do
      described_class.new.store_original_url(short_code, original_url)
      expect(described_class.new.fetch_original_url(short_code)).to eq(original_url)
    end

    it "returns nil if cache key does not exist" do
      expect(described_class.new.fetch_original_url("nonexistent")).to be_nil
    end
  end
end
