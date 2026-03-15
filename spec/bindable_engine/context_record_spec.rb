# frozen_string_literal: true

RSpec.describe BindableEngine::ContextRecord do
  describe "#initialize" do
    it "creates a record with required attributes" do
      record = described_class.new(
        action: :read,
        target: "users",
        payload: { id: "42" }
      )

      expect(record.action).to eq(:read)
      expect(record.target).to eq("users")
      expect(record.payload[:id]).to eq("42")
      expect(record.id).to be_a(String)
      expect(record.timestamp).to be_a(Time)
    end

    it "assigns a UUID" do
      record = described_class.new(action: :read, target: "users")
      expect(record.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "sets default context to VV_CONTEXT" do
      record = described_class.new(action: :read, target: "users")
      expect(record.context).to eq(described_class::VV_CONTEXT)
    end

    it "accepts a custom context" do
      record = described_class.new(
        action: :read,
        target: "users",
        context: "https://example.com/ns#"
      )
      expect(record.context).to eq("https://example.com/ns#")
    end

    it "defaults payload to empty hash" do
      record = described_class.new(action: :read, target: "users")
      expect(record.payload).to eq({})
    end

    it "defaults metadata to empty hash" do
      record = described_class.new(action: :read, target: "users")
      expect(record.metadata).to eq({})
    end

    it "raises ValidationError for invalid action" do
      expect {
        described_class.new(action: :explode, target: "users")
      }.to raise_error(BindableEngine::ValidationError, /Invalid action/)
    end

    it "accepts all valid actions" do
      %i[create read update delete list execute].each do |action|
        record = described_class.new(action: action, target: "users")
        expect(record.action).to eq(action)
      end
    end
  end

  describe "immutability" do
    it "freezes the payload" do
      record = described_class.new(
        action: :read,
        target: "users",
        payload: { name: "Alice" }
      )
      expect(record.payload).to be_frozen
      expect { record.payload[:name] = "Bob" }.to raise_error(FrozenError)
    end

    it "deep freezes nested payload" do
      record = described_class.new(
        action: :read,
        target: "users",
        payload: { tags: ["admin", "user"] }
      )
      expect(record.payload[:tags]).to be_frozen
    end

    it "freezes metadata" do
      record = described_class.new(
        action: :read,
        target: "users",
        metadata: { actor: "agent-1" }
      )
      expect(record.metadata).to be_frozen
    end
  end

  describe "#to_h" do
    it "returns a hash with @context" do
      record = described_class.new(action: :read, target: "users")
      h = record.to_h
      expect(h["@context"]).to eq(described_class::VV_CONTEXT)
      expect(h[:action]).to eq(:read)
      expect(h[:target]).to eq("users")
      expect(h[:timestamp]).to be_a(String)
    end
  end

  describe "#json_ld?" do
    it "returns false for default context" do
      record = described_class.new(action: :read, target: "users")
      expect(record.json_ld?).to be false
    end

    it "returns true for custom context" do
      record = described_class.new(
        action: :read,
        target: "users",
        context: "https://example.com/ns#"
      )
      expect(record.json_ld?).to be true
    end
  end
end
