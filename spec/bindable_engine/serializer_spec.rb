# frozen_string_literal: true

RSpec.describe BindableEngine::Serializer do
  let(:context_url) { "https://vv.dev/ns/planning" }
  let(:type_name) { "Plan" }

  describe ".to_json_ld" do
    it "adds @context, @type, and @id" do
      result = described_class.to_json_ld(
        { id: "42", title: "Q1 Plan", status: "active" },
        context_url: context_url, type_name: type_name
      )
      expect(result["@context"]).to eq(context_url)
      expect(result["@type"]).to eq(type_name)
      expect(result["@id"]).to eq("42")
      expect(result["title"]).to eq("Q1 Plan")
      expect(result["status"]).to eq("active")
    end

    it "handles string keys" do
      result = described_class.to_json_ld(
        { "id" => "42", "title" => "Q1 Plan" },
        context_url: context_url, type_name: type_name
      )
      expect(result["@id"]).to eq("42")
      expect(result["title"]).to eq("Q1 Plan")
    end

    it "omits @id when no id present" do
      result = described_class.to_json_ld(
        { title: "Untitled" },
        context_url: context_url, type_name: type_name
      )
      expect(result).not_to have_key("@id")
    end

    it "does not duplicate existing @ keys from data" do
      result = described_class.to_json_ld(
        { id: "1", "@context" => "ignored", "@type" => "ignored" },
        context_url: context_url, type_name: type_name
      )
      expect(result["@context"]).to eq(context_url)
      expect(result["@type"]).to eq(type_name)
    end
  end

  describe ".to_json_ld_collection" do
    let(:items) do
      [
        { id: "1", title: "Plan A" },
        { id: "2", title: "Plan B" }
      ]
    end

    it "wraps items with collection type" do
      result = described_class.to_json_ld_collection(
        items, context_url: context_url, type_name: type_name
      )
      expect(result["@context"]).to eq(context_url)
      expect(result["@type"]).to eq("PlanCollection")
      expect(result["total"]).to eq(2)
    end

    it "wraps each item with @type and @id" do
      result = described_class.to_json_ld_collection(
        items, context_url: context_url, type_name: type_name
      )
      expect(result["items"].size).to eq(2)
      expect(result["items"][0]["@type"]).to eq(type_name)
      expect(result["items"][0]["@id"]).to eq("1")
      expect(result["items"][0]["title"]).to eq("Plan A")
    end

    it "handles empty collections" do
      result = described_class.to_json_ld_collection(
        [], context_url: context_url, type_name: type_name
      )
      expect(result["items"]).to be_empty
      expect(result["total"]).to eq(0)
    end
  end

  describe ".to_json_ld_with_refs" do
    let(:registry) { BindableEngine::BindableRegistry.instance }

    let(:plans_class) do
      Class.new do
        include BindableEngine::Bindable
        bind_as "planner-plan"
        def read(ctx)
          BindableEngine::Result.success({ "id" => ctx.payload[:id], "title" => "Resolved Plan" })
        end
      end
    end

    before do
      registry.reset!
      registry.register(plans_class.new)
    end

    it "resolves Ref objects and produces JSON-LD" do
      resolver = BindableEngine::RefResolver.new(registry: registry)
      data = {
        id: "conn-1",
        name: "Connection",
        source: BindableEngine::Ref.new(target: "planner-plan", id: "abc")
      }
      result = described_class.to_json_ld_with_refs(
        data, context_url: context_url, type_name: "Connection", resolver: resolver
      )
      expect(result["@context"]).to eq(context_url)
      expect(result["@type"]).to eq("Connection")
      expect(result["source"]["title"]).to eq("Resolved Plan")
    end
  end
end
