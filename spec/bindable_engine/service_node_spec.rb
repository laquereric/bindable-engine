# frozen_string_literal: true

RSpec.describe BindableEngine::ServiceNode do
  let(:bindable_class) do
    Class.new do
      include BindableEngine::Bindable
      bind_as "Orders"

      def create(context_record)
        { order_id: "ord-001", items: context_record.payload[:items] }
      end

      def read(context_record)
        { order_id: context_record.payload[:id], status: "pending" }
      end
    end
  end

  let(:node) { described_class.new(name: "order-service") }
  let(:bindable) { bindable_class.new }

  before do
    BindableEngine::BindableRegistry.instance.reset!
    node.register(bindable)
  end

  describe "#register" do
    it "registers a bindable component" do
      expect(node.registered_bindables).to include("Orders")
    end

    it "registers in the global BindableRegistry" do
      expect(BindableEngine::BindableRegistry.instance.names).to include("Orders")
    end
  end

  describe "#send_message" do
    it "routes messages through the moderator to bindables" do
      record = BindableEngine::ContextRecord.new(
        action: :create,
        target: "Orders",
        payload: { items: ["widget"] }
      )
      result = node.send_message(record)
      expect(result[:order_id]).to eq("ord-001")
    end

    it "logs messages passing through the moderator" do
      record = BindableEngine::ContextRecord.new(
        action: :read,
        target: "Orders",
        payload: { id: "ord-001" }
      )
      node.send_message(record)
      expect(node.log.size).to eq(1)
      expect(node.log.first[:status]).to eq(:completed)
    end

    it "returns a not_found Failure for unregistered targets" do
      record = BindableEngine::ContextRecord.new(
        action: :read,
        target: "Unknown",
        payload: {}
      )
      result = node.send_message(record)
      expect(result).to be_a(BindableEngine::Result)
      expect(result.failure?).to be true
      expect(result.failure[:code]).to eq(:not_found)
      expect(result.failure[:message]).to include("No bindable")
    end
  end

  describe "authentication and authorization" do
    let(:secure_node) do
      described_class.new(
        name: "secure-node",
        authenticator: ->(record) { record.metadata[:token] == "valid" },
        authorizer: ->(record) { record.metadata[:role] == "admin" }
      )
    end

    before { secure_node.register(bindable) }

    it "returns unauthorized Failure for unauthenticated messages" do
      record = BindableEngine::ContextRecord.new(
        action: :read,
        target: "Orders",
        metadata: { token: "invalid", role: "admin" }
      )
      result = secure_node.send_message(record)
      expect(result).to be_a(BindableEngine::Result)
      expect(result.failure[:code]).to eq(:unauthorized)
    end

    it "returns forbidden Failure for unauthorized messages" do
      record = BindableEngine::ContextRecord.new(
        action: :read,
        target: "Orders",
        metadata: { token: "valid", role: "guest" }
      )
      result = secure_node.send_message(record)
      expect(result).to be_a(BindableEngine::Result)
      expect(result.failure[:code]).to eq(:forbidden)
    end

    it "permits properly authenticated and authorized messages" do
      record = BindableEngine::ContextRecord.new(
        action: :read,
        target: "Orders",
        payload: { id: "ord-001" },
        metadata: { token: "valid", role: "admin" }
      )
      result = secure_node.send_message(record)
      expect(result[:status]).to eq("pending")
    end
  end
end
