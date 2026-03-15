# frozen_string_literal: true

RSpec.describe BindableEngine::Result do
  describe ".success" do
    let(:result) { described_class.success({ id: "42", name: "Alice" }) }

    it "is a success" do
      expect(result.success?).to be true
    end

    it "is not a failure" do
      expect(result.failure?).to be false
    end

    it "unwraps to the value" do
      expect(result.value!).to eq({ id: "42", name: "Alice" })
    end

    it "returns nil for failure" do
      expect(result.failure).to be_nil
    end

    it "is frozen" do
      expect(result).to be_frozen
    end
  end

  describe ".failure" do
    let(:result) { described_class.failure(code: :not_found, message: "User not found") }

    it "is not a success" do
      expect(result.success?).to be false
    end

    it "is a failure" do
      expect(result.failure?).to be true
    end

    it "raises on value!" do
      expect { result.value! }.to raise_error(RuntimeError, /Cannot unwrap/)
    end

    it "returns the error hash" do
      expect(result.failure[:code]).to eq(:not_found)
      expect(result.failure[:message]).to eq("User not found")
    end

    it "includes extra keys in the error hash" do
      result = described_class.failure(code: :internal_error, message: "boom", trace: ["line1"])
      expect(result.failure[:trace]).to eq(["line1"])
    end

    it "is frozen" do
      expect(result).to be_frozen
    end
  end

  describe "#map" do
    it "transforms the success value" do
      result = described_class.success(10).map { |v| v * 2 }
      expect(result.value!).to eq(20)
    end

    it "returns self on failure" do
      result = described_class.failure(code: :not_found, message: "gone")
      mapped = result.map { |v| v * 2 }
      expect(mapped.failure[:code]).to eq(:not_found)
    end
  end

  describe "#bind" do
    it "chains result-returning operations" do
      result = described_class.success(5).bind { |v| described_class.success(v + 1) }
      expect(result.value!).to eq(6)
    end

    it "returns self on failure" do
      result = described_class.failure(code: :not_found, message: "gone")
      bound = result.bind { |v| described_class.success(v + 1) }
      expect(bound.failure[:code]).to eq(:not_found)
    end
  end
end
