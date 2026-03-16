# frozen_string_literal: true

RSpec.describe BindableEngine::Stores::MemoryStore do
  subject(:store) { described_class.new }

  describe "#save" do
    it "returns a success result" do
      result = store.save("1", { name: "Alice" })
      expect(result).to be_success
    end

    it "stores the record with string keys" do
      store.save("1", { name: "Alice" })
      result = store.find("1")
      expect(result.value!["name"]).to eq("Alice")
    end

    it "includes id in returned data" do
      result = store.save("1", { name: "Alice" })
      expect(result.value!["id"]).to eq("1")
    end

    it "upserts existing records" do
      store.save("1", { name: "Alice" })
      store.save("1", { name: "Bob" })
      expect(store.size).to eq(1)
      expect(store.find("1").value!["name"]).to eq("Bob")
    end

    it "converts id to string" do
      store.save(42, { name: "Alice" })
      expect(store.find("42")).to be_success
    end
  end

  describe "#find" do
    it "returns success with the record" do
      store.save("1", { name: "Alice" })
      result = store.find("1")
      expect(result).to be_success
      expect(result.value!["name"]).to eq("Alice")
    end

    it "returns failure for missing records" do
      result = store.find("missing")
      expect(result).to be_failure
      expect(result.failure[:code]).to eq(:not_found)
    end
  end

  describe "#query" do
    before do
      store.save("1", { name: "Alice", role: "admin" })
      store.save("2", { name: "Bob", role: "user" })
      store.save("3", { name: "Carol", role: "admin" })
    end

    it "returns all records with no criteria" do
      result = store.query
      expect(result).to be_success
      expect(result.value!.size).to eq(3)
    end

    it "filters by criteria" do
      result = store.query(role: "admin")
      expect(result).to be_success
      expect(result.value!.size).to eq(2)
      expect(result.value!.map { |r| r["name"] }).to contain_exactly("Alice", "Carol")
    end

    it "returns empty array for no matches" do
      result = store.query(role: "superadmin")
      expect(result).to be_success
      expect(result.value!).to be_empty
    end
  end

  describe "#destroy" do
    it "removes the record" do
      store.save("1", { name: "Alice" })
      result = store.destroy("1")
      expect(result).to be_success
      expect(store.find("1")).to be_failure
    end

    it "returns failure for missing records" do
      result = store.destroy("missing")
      expect(result).to be_failure
      expect(result.failure[:code]).to eq(:not_found)
    end
  end

  describe "#clear!" do
    it "removes all records" do
      store.save("1", { name: "Alice" })
      store.save("2", { name: "Bob" })
      store.clear!
      expect(store.size).to eq(0)
    end
  end

  describe "#size" do
    it "returns the number of records" do
      expect(store.size).to eq(0)
      store.save("1", { name: "Alice" })
      expect(store.size).to eq(1)
    end
  end

  describe "thread safety" do
    it "handles concurrent writes" do
      threads = 10.times.map do |i|
        Thread.new { store.save(i.to_s, { value: i }) }
      end
      threads.each(&:join)
      expect(store.size).to eq(10)
    end
  end
end
