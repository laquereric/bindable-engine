# frozen_string_literal: true

RSpec.describe BindableEngine::Ref do
  subject(:ref) { described_class.new(target: "planner-plan", id: "abc-123", label: "Q1 Plan") }

  describe "#initialize" do
    it "sets target, id, and label" do
      expect(ref.target).to eq("planner-plan")
      expect(ref.id).to eq("abc-123")
      expect(ref.label).to eq("Q1 Plan")
    end

    it "freezes the object" do
      expect(ref).to be_frozen
    end

    it "converts target and id to strings" do
      r = described_class.new(target: :plans, id: 42)
      expect(r.target).to eq("plans")
      expect(r.id).to eq("42")
    end

    it "allows nil label" do
      r = described_class.new(target: "plans", id: "1")
      expect(r.label).to be_nil
    end
  end

  describe "#to_h" do
    it "returns a hash with @type Ref" do
      h = ref.to_h
      expect(h["@type"]).to eq("Ref")
      expect(h["target"]).to eq("planner-plan")
      expect(h["id"]).to eq("abc-123")
      expect(h["label"]).to eq("Q1 Plan")
    end

    it "omits label when nil" do
      r = described_class.new(target: "plans", id: "1")
      expect(r.to_h).not_to have_key("label")
    end
  end

  describe "equality" do
    it "is equal to another Ref with same target and id" do
      other = described_class.new(target: "planner-plan", id: "abc-123", label: "Different Label")
      expect(ref).to eq(other)
      expect(ref).to eql(other)
    end

    it "is not equal to Ref with different target" do
      other = described_class.new(target: "other", id: "abc-123")
      expect(ref).not_to eq(other)
    end

    it "is not equal to Ref with different id" do
      other = described_class.new(target: "planner-plan", id: "other")
      expect(ref).not_to eq(other)
    end

    it "is not equal to non-Ref objects" do
      expect(ref).not_to eq("planner-plan:abc-123")
    end
  end

  describe "#hash" do
    it "has same hash for equal Refs" do
      other = described_class.new(target: "planner-plan", id: "abc-123")
      expect(ref.hash).to eq(other.hash)
    end

    it "works as hash key" do
      h = { ref => "value" }
      other = described_class.new(target: "planner-plan", id: "abc-123")
      expect(h[other]).to eq("value")
    end
  end

  describe "#inspect" do
    it "returns a readable string" do
      expect(ref.inspect).to include("planner-plan")
      expect(ref.inspect).to include("abc-123")
    end
  end
end
