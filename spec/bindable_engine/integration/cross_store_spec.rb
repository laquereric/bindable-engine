# frozen_string_literal: true

RSpec.describe "Cross-store integration" do
  let(:registry) { BindableEngine::BindableRegistry.instance }

  # A Bindable backed by MemoryStore
  let(:plans_class) do
    Class.new do
      include BindableEngine::Bindable
      bind_as "planner-plan"
      persists_with :memory, context_url: "https://vv.dev/ns/planning", type_name: "Plan"

      def initialize
        @store = BindableEngine::Stores::MemoryStore.new
        @store.save("plan-1", { "title" => "Q1 Plan", "status" => "active" })
        @store.save("plan-2", { "title" => "Q2 Plan", "status" => "draft" })
      end

      def read(context_record)
        id = context_record.payload[:id]
        result = @store.find(id)
        return result unless result.success?

        config = self.class.persistence_config
        data = BindableEngine::Serializer.to_json_ld(
          result.value!, context_url: config[:context_url], type_name: config[:type_name]
        )
        BindableEngine::Result.success(data)
      end

      def list(_context_record)
        result = @store.query
        return result unless result.success?

        config = self.class.persistence_config
        data = BindableEngine::Serializer.to_json_ld_collection(
          result.value!, context_url: config[:context_url], type_name: config[:type_name]
        )
        BindableEngine::Result.success(data)
      end
    end
  end

  # A Bindable that references another via Ref
  let(:connections_class) do
    Class.new do
      include BindableEngine::Bindable
      bind_as "planner-connection"
      persists_with :memory, context_url: "https://vv.dev/ns/planning", type_name: "Connection"

      def initialize
        @store = BindableEngine::Stores::MemoryStore.new
        @store.save("conn-1", { "name" => "Link A-B" })
      end

      def read(context_record)
        id = context_record.payload[:id]
        result = @store.find(id)
        return result unless result.success?

        data = result.value!.merge(
          "source" => BindableEngine::Ref.new(target: "planner-plan", id: "plan-1"),
          "target" => BindableEngine::Ref.new(target: "planner-plan", id: "plan-2")
        )
        config = self.class.persistence_config
        resolver = BindableEngine::RefResolver.new
        BindableEngine::Result.success(
          BindableEngine::Serializer.to_json_ld_with_refs(
            data, context_url: config[:context_url], type_name: config[:type_name], resolver: resolver
          )
        )
      end
    end
  end

  before do
    registry.reset!
    registry.register(plans_class.new)
    registry.register(connections_class.new)
  end

  it "resolves cross-domain Refs through the registry" do
    ctx = BindableEngine::ContextRecord.new(
      action: :read, target: "planner-connection", payload: { id: "conn-1" }
    )
    result = registry.instance_for("planner-connection").read(ctx)
    expect(result).to be_success

    data = result.value!
    expect(data["@type"]).to eq("Connection")
    expect(data["@context"]).to eq("https://vv.dev/ns/planning")
    expect(data["source"]["@type"]).to eq("Plan")
    expect(data["source"]["title"]).to eq("Q1 Plan")
    expect(data["target"]["title"]).to eq("Q2 Plan")
  end

  it "produces JSON-LD from MemoryStore Bindable" do
    ctx = BindableEngine::ContextRecord.new(
      action: :read, target: "planner-plan", payload: { id: "plan-1" }
    )
    result = registry.instance_for("planner-plan").read(ctx)
    expect(result).to be_success

    data = result.value!
    expect(data["@context"]).to eq("https://vv.dev/ns/planning")
    expect(data["@type"]).to eq("Plan")
    expect(data["@id"]).to eq("plan-1")
    expect(data["title"]).to eq("Q1 Plan")
  end

  it "produces JSON-LD collections" do
    ctx = BindableEngine::ContextRecord.new(action: :list, target: "planner-plan")
    result = registry.instance_for("planner-plan").list(ctx)
    expect(result).to be_success

    data = result.value!
    expect(data["@type"]).to eq("PlanCollection")
    expect(data["total"]).to eq(2)
    expect(data["items"].first["@type"]).to eq("Plan")
  end

  it "includes persistence metadata in the registry manifest" do
    entry = registry.manifest.find { |e| e[:name] == "planner-plan" }
    expect(entry[:persistence][:strategy]).to eq(:memory)
    expect(entry[:persistence][:context_url]).to eq("https://vv.dev/ns/planning")
    expect(entry[:persistence][:type_name]).to eq("Plan")
  end

  it "degrades gracefully when a ref target is unknown" do
    # Register a connection that refs a non-existent Bindable
    broken_class = Class.new do
      include BindableEngine::Bindable
      bind_as "broken-conn"

      def read(_ctx)
        data = {
          "id" => "x",
          "ref" => BindableEngine::Ref.new(target: "nonexistent", id: "1")
        }
        resolver = BindableEngine::RefResolver.new
        BindableEngine::Result.success(resolver.resolve_refs_in(data))
      end
    end
    registry.register(broken_class.new)

    ctx = BindableEngine::ContextRecord.new(action: :read, target: "broken-conn", payload: { id: "x" })
    result = registry.instance_for("broken-conn").read(ctx)
    expect(result).to be_success
    expect(result.value!["ref"]["@type"]).to eq("Ref")
    expect(result.value!["ref"]["target"]).to eq("nonexistent")
  end
end
