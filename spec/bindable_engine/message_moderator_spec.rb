# frozen_string_literal: true

RSpec.describe BindableEngine::MessageModerator do
  let(:bindable_class) do
    Class.new do
      include BindableEngine::Bindable
      bind_as "Inventory"

      def read(_context_record)
        { sku: "ABC", quantity: 42 }
      end
    end
  end

  let(:moderator) { described_class.new(node_name: "warehouse") }
  let(:bindable) { bindable_class.new }

  before { moderator.register(bindable) }

  describe "#register" do
    it "tracks registered bindables" do
      expect(moderator.registered_bindables).to include("Inventory")
    end
  end

  describe "#route" do
    it "delivers messages to the correct bindable" do
      record = BindableEngine::ContextRecord.new(
        action: :read,
        target: "Inventory"
      )
      result = moderator.route(record)
      expect(result[:sku]).to eq("ABC")
    end

    it "logs successful operations" do
      record = BindableEngine::ContextRecord.new(
        action: :read,
        target: "Inventory"
      )
      moderator.route(record)

      entry = moderator.log.last
      expect(entry[:status]).to eq(:completed)
      expect(entry[:node]).to eq("warehouse")
      expect(entry[:action]).to eq(:read)
    end

    it "returns a Failure result for unknown targets" do
      record = BindableEngine::ContextRecord.new(
        action: :read,
        target: "NonExistent"
      )
      result = moderator.route(record)
      expect(result).to be_a(BindableEngine::Result)
      expect(result.failure?).to be true
      expect(result.failure[:code]).to eq(:not_found)
      expect(moderator.log.last[:status]).to eq(:failed)
    end

    it "returns unauthorized Failure when authentication fails" do
      auth_mod = described_class.new(
        node_name: "secure",
        authenticator: ->(_record) { false }
      )
      auth_mod.register(bindable)
      record = BindableEngine::ContextRecord.new(
        action: :read,
        target: "Inventory"
      )
      result = auth_mod.route(record)
      expect(result).to be_a(BindableEngine::Result)
      expect(result.failure[:code]).to eq(:unauthorized)
    end

    it "returns forbidden Failure when authorization fails" do
      authz_mod = described_class.new(
        node_name: "restricted",
        authorizer: ->(_record) { false }
      )
      authz_mod.register(bindable)
      record = BindableEngine::ContextRecord.new(
        action: :read,
        target: "Inventory"
      )
      result = authz_mod.route(record)
      expect(result).to be_a(BindableEngine::Result)
      expect(result.failure[:code]).to eq(:forbidden)
    end
  end
end
