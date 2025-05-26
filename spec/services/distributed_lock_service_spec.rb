require "rails_helper"

RSpec.describe DistributedLockService do
  subject(:service){described_class.new}

  let(:redis_conn){instance_double(Redis)}
  let(:redis_pool) do
    ConnectionPool.new(size: 1, timeout: 5){redis_conn}
  end
  let(:lock_key){"lock:short_link"}
  let(:lock_value){"test-value"}

  before do
    stub_const("LockRedis", redis_pool)
    stub_const("DistributedLockService::RETRY_COUNT", 3)
    stub_const("DistributedLockService::RETRY_DELAY", 0)
    stub_const("DistributedLockService::TTL", 5)
  end

  describe "#with_lock" do
    context "when lock is acquired successfully" do
      before do
        allow(SecureRandom).to receive(:uuid).and_return(lock_value)
        allow(redis_conn).to receive(:set).and_return(true)
        allow(redis_conn).to receive(:get).and_return(lock_value)
        allow(redis_conn).to receive(:del)
      end

      it "returns the block result" do
        result = nil
        expect{result = service.with_lock{"locked"}}.not_to raise_error
        expect(result).to eq("locked")
      end

      it "calls set, get and del on redis" do
        service.with_lock{"locked"}
        aggregate_failures do
          expect(redis_conn).to have_received(:set).once
          expect(redis_conn).to have_received(:get).once
          expect(redis_conn).to have_received(:del).once
        end
      end
    end

    context "when lock is not acquired after retries" do
      before do
        allow(redis_conn).to receive(:set).and_return(false)
      end

      it "raises LockAcquisitionFailedError" do
        expect{service.with_lock {}}.to raise_error(LockAcquisitionFailedError)
        expect(redis_conn).to have_received(:set).exactly(3).times
      end
    end

    context "when lock is stolen during execution" do
      before do
        allow(SecureRandom).to receive(:uuid).and_return(lock_value)
        allow(redis_conn).to receive(:set).and_return(true)
        allow(redis_conn).to receive(:get).and_return("other_thread")
        allow(redis_conn).to receive(:del)
      end

      it "does not delete the lock if not owner" do
        expect{service.with_lock {}}.not_to raise_error
        expect(redis_conn).not_to have_received(:del)
      end
    end
  end

  describe "#acquire_lock" do
    it "sets a new lock if not already set" do
      expect(redis_conn).to receive(:set)
        .with(lock_key, lock_value, nx: true, ex: 5)
        .and_return(true)

      expect(service.send(:acquire_lock, lock_value)).to be_truthy
    end

    it "returns false if lock already exists" do
      expect(redis_conn).to receive(:set)
        .with(lock_key, lock_value, nx: true, ex: 5)
        .and_return(false)

      expect(service.send(:acquire_lock, lock_value)).to be_falsey
    end
  end

  describe "#release_lock_if_owner" do
    context "when still the owner" do
      it "deletes the lock" do
        allow(redis_conn).to receive(:get).and_return(lock_value)
        expect(redis_conn).to receive(:del).with(lock_key)

        service.send(:release_lock_if_owner, lock_value)
      end
    end

    context "when owned by someone else" do
      it "does not delete the lock" do
        allow(redis_conn).to receive(:get).and_return("someone-else")
        expect(redis_conn).not_to receive(:del)

        service.send(:release_lock_if_owner, lock_value)
      end
    end
  end
end
