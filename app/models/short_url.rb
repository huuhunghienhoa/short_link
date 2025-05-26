class ShortUrl < ApplicationRecord
  validates :original_url, presence: true, url: true
  validates :short_code, presence: true, uniqueness: true
end
