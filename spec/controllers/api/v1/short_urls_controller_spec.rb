require "rails_helper"

RSpec.describe Api::V1::ShortUrlsController, type: [:controller, :api] do
  let(:valid_url){"https://example.com/test"}
  let(:short_code){"AB567NVK"}
  let(:invalid_url){"example.com"}

  before{clear_redis}

  describe "Rate limit" do
    it "allows requests under the limit" do
      5.times do
        get :decode, params: {short_code: short_code}
        expect(response.status).not_to eq(429)
      end
    end

    it "blocks requests over the limit" do
      51.times do
        get :decode, params: {short_code: short_code}
      end
      expect(response.status).to eq(429)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Rate limit exceeded")
    end
  end

  describe "POST /api/encode" do
    context "when encodes a URL successfully" do
      before do
        allow_any_instance_of(EncodeService).to receive(:generate_short_code).and_return short_code
        post :encode, params: {url: valid_url}
      end

      it "Return short_code" do
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["short_code"]).to eq short_code
      end

      it "Correct number of ShortUrl" do
        expect(ShortUrl.count).to eq 1
      end

      it "Cached for short_code" do
        short_code = ShortUrl.first.short_code
        cache = CacheRedis.with{|con| con.get("#{CacheService::CODE_NAMESPACE}:#{short_code}")}
        expect(cache).to eq valid_url
      end

      it "Cached for original_url" do
        short_code = ShortUrl.first.short_code
        cache = CacheRedis.with{|con| con.get("#{CacheService::URL_NAMESPACE}:#{Digest::SHA256.hexdigest(valid_url)}")}
        expect(cache).to eq short_code
      end
    end

    context "When encode a URL failed" do
      context "Short_code already exists" do
        let!(:short_link){ShortUrl.create!(original_url: valid_url, short_code: short_code)}

        before do
          allow_any_instance_of(EncodeService).to receive(:generate_short_code).and_return short_code
          post :encode, params: {url: valid_url}
        end

        it "return error code" do
          expect(response.status).to eq(422)
        end

        it "return error message" do
          json = JSON.parse(response.body)
          expect(json["error"]).to eq("Short code has already been taken")
        end

        include_examples "an empty cache"
      end

      context "When URL is invalid" do
        before do
          post :encode, params: {url: invalid_url}
        end

        it "Return status error" do
          expect(response.status).to eq(422)
        end

        it "Return message error" do
          json = JSON.parse(response.body)
          expect(json["error"]).to eq("Original url must be a valid URL")
        end

        include_examples "an empty cache"
      end
    end
  end

  describe "GET /api/decode" do
    let!(:short_link){ShortUrl.create!(original_url: valid_url, short_code: short_code)}

    context "when decode successfully" do
      it "decodes a valid short_code" do
        get :decode, params: {short_code: short_link.short_code}
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["original_url"]).to eq(valid_url)
      end

      it "Cached decode result in Redis" do
        expect(CacheRedis.with{|con| con.get("#{CacheService::CODE_NAMESPACE}:#{short_code}")}).to be_nil

        get :decode, params: {short_code: short_link.short_code}
        expect(response).to have_http_status(:ok)

        # Cache for short_code existed after decode
        expect(CacheRedis.with{|con| con.get("#{CacheService::CODE_NAMESPACE}:#{short_code}")}).to eq(valid_url)

        # TTL > 0
        ttl = CacheRedis.with{|con| con.ttl("#{CacheService::CODE_NAMESPACE}:#{short_code}")}
        expect(ttl).to be > 0
      end
    end

    context "when decode failed" do
      before do
        post :decode, params: {short_code: "notfound"}
      end

      it "returns 404 for unknown short_code" do
        expect(response).to have_http_status(:not_found)
      end

      it "return error messsage" do
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Short code not found")
      end

      include_examples "an empty cache"
    end
  end
end
