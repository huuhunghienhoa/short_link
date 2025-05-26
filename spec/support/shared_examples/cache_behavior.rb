RSpec.shared_examples "an empty cache" do
  it "Cache does not exist" do
    caches = CacheRedis.with(&:keys)
    expect(caches).to match_array([])
  end
end
