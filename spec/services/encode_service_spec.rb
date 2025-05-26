require "rails_helper"

RSpec.describe EncodeService do
  let(:original_url){"https://example.com"}
  let(:ip_address){"127.0.0.1"}
  let!(:short_code){"abc123"}

  before{clear_redis}

  describe "#call" do
    context "when original_url already exists in cache" do
      before do
        CacheService.new.store_short_code_by_url(original_url, short_code)
      end

      it "returns existing short_code" do
        short_code = described_class.new(original_url, ip_address).call
        expect(short_code).to eq short_code
      end
    end

    context "when URL is new" do
      it "creates a new short_code" do
        expect do
          described_class.new(original_url, ip_address).call
        end.to change(ShortUrl, :count).by(1)
      end
    end
  end
end
