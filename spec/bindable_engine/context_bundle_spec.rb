# frozen_string_literal: true

RSpec.describe BindableEngine::ContextBundle do
  describe "#initialize" do
    it "creates a bundle with valid attributes" do
      bundle = described_class.new(
        id: "user-context",
        assembly_mode: "parallel",
        views: [{ concept: "users" }]
      )

      expect(bundle.id).to eq("user-context")
      expect(bundle.assembly_mode).to eq("parallel")
      expect(bundle.views).to eq([{ concept: "users" }])
    end

    it "defaults assembly_mode to parallel" do
      bundle = described_class.new(id: "test")
      expect(bundle.assembly_mode).to eq("parallel")
    end

    it "defaults views to empty array" do
      bundle = described_class.new(id: "test")
      expect(bundle.views).to eq([])
    end

    it "accepts all valid modes" do
      %w[parallel sequential lazy].each do |mode|
        bundle = described_class.new(id: "test", assembly_mode: mode)
        expect(bundle.assembly_mode).to eq(mode)
      end
    end

    it "raises ValidationError for invalid mode" do
      expect {
        described_class.new(id: "test", assembly_mode: "invalid")
      }.to raise_error(BindableEngine::ValidationError, /Invalid assembly_mode/)
    end

    it "is frozen" do
      bundle = described_class.new(id: "test")
      expect(bundle).to be_frozen
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      bundle = described_class.new(
        id: "ctx-1",
        assembly_mode: "sequential",
        views: [{ concept: "users" }]
      )
      h = bundle.to_h
      expect(h[:id]).to eq("ctx-1")
      expect(h[:assembly_mode]).to eq("sequential")
      expect(h[:views]).to eq([{ concept: "users" }])
    end
  end
end
