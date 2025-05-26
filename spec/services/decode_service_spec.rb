require "rails_helper"

RSpec.describe DecodeService do
  let(:short_code){"AbcGH9Dh"}
  let(:ip_address){"127.0.0.1"}
  let!(:mapping){ShortUrl.create!(original_url: "https://example.com", short_code: short_code)}

  describe "#call" do
    context "when short_code exists" do
      it "returns original_url" do
        url = described_class.new(short_code, ip_address).call
        expect(url).to eq("https://example.com")
      end
    end

    context "when short_code not found" do
      it "raises ActiveRecord::RecordNotFound" do
        expect do
          described_class.new("not_exist", ip_address).call
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
