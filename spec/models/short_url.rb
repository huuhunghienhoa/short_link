require "rails_helper"

RSpec.describe ShortUrl, type: :model do
  it{is_expected.to validate_presence_of(:original_url)}
  it{is_expected.to validate_presence_of(:short_code)}
  it{is_expected.to validate_uniqueness_of(:short_code)}
end
