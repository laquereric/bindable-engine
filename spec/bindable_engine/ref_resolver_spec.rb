# frozen_string_literal: true

RSpec.describe BindableEngine::RefResolver do
  let(:registry) { BindableEngine::BindableRegistry.instance }

  let(:plans_class) do
    Class.new do
      include BindableEngine::Bindable
      bind_as "planner-plan"

      def read(context_record)
        id = context_record.payload[:id]
        BindableEngine::Result.success({ "id" => id, "title" => "Plan #{id}" })
      end
    end
  end

  let(:resolver) { described_class.new(registry: registry) }

  before do
    registry.reset!
    registry.register(plans_class.new)
  end

  describe "#resolve" do
    it "resolves a Ref through the registry" do
      ref = BindableEngine::Ref.new(target: "planner-plan", id: "abc")
      result = resolver.resolve(ref)
      expect(result).to be_success
      expect(result.value!["title"]).to eq("Plan abc")
    end

    it "returns failure for unknown targets" do
      ref = BindableEngine::Ref.new(target: "nonexistent", id: "1")
      result = resolver.resolve(ref)
      expect(result).to be_failure
      expect(result.failure[:code]).to eq(:not_found)
    end

    it "wraps non-Result return values" do
      raw_class = Class.new do
        include BindableEngine::Bindable
        bind_as "raw-data"
        def read(_ctx)
          { "id" => "1", "raw" => true }
        end
      end
      registry.register(raw_class.new)

      ref = BindableEngine::Ref.new(target: "raw-data", id: "1")
      result = resolver.resolve(ref)
      expect(result).to be_success
      expect(result.value!["raw"]).to be true
    end
  end

  describe "#resolve_all" do
    it "returns a map of Ref => Result" do
      refs = [
        BindableEngine::Ref.new(target: "planner-plan", id: "1"),
        BindableEngine::Ref.new(target: "planner-plan", id: "2")
      ]
      results = resolver.resolve_all(refs)
      expect(results.size).to eq(2)
      expect(results[refs[0]]).to be_success
      expect(results[refs[1]]).to be_success
    end

    it "includes failures for unknown targets" do
      refs = [
        BindableEngine::Ref.new(target: "planner-plan", id: "1"),
        BindableEngine::Ref.new(target: "nonexistent", id: "2")
      ]
      results = resolver.resolve_all(refs)
      expect(results[refs[0]]).to be_success
      expect(results[refs[1]]).to be_failure
    end
  end

  describe "#resolve_refs_in" do
    it "replaces Ref values in a hash" do
      data = {
        "name" => "Connection",
        "source" => BindableEngine::Ref.new(target: "planner-plan", id: "abc")
      }
      result = resolver.resolve_refs_in(data)
      expect(result["source"]["title"]).to eq("Plan abc")
    end

    it "replaces Refs in arrays" do
      data = [
        BindableEngine::Ref.new(target: "planner-plan", id: "1"),
        BindableEngine::Ref.new(target: "planner-plan", id: "2")
      ]
      result = resolver.resolve_refs_in(data)
      expect(result[0]["title"]).to eq("Plan 1")
      expect(result[1]["title"]).to eq("Plan 2")
    end

    it "degrades failed resolutions to Ref#to_h" do
      data = {
        "ref" => BindableEngine::Ref.new(target: "nonexistent", id: "1")
      }
      result = resolver.resolve_refs_in(data)
      expect(result["ref"]["@type"]).to eq("Ref")
      expect(result["ref"]["target"]).to eq("nonexistent")
    end

    it "handles nested structures" do
      data = {
        "outer" => {
          "inner" => BindableEngine::Ref.new(target: "planner-plan", id: "nested")
        }
      }
      result = resolver.resolve_refs_in(data)
      expect(result["outer"]["inner"]["title"]).to eq("Plan nested")
    end

    it "respects MAX_DEPTH to prevent circular refs" do
      deeply_nested = { "a" => { "b" => { "c" => { "d" => BindableEngine::Ref.new(target: "planner-plan", id: "deep") } } } }
      result = resolver.resolve_refs_in(deeply_nested)
      # At depth 3, the Ref should not be resolved
      expect(result["a"]["b"]["c"]["d"]).to be_a(BindableEngine::Ref)
    end

    it "passes through non-Ref, non-collection values" do
      data = { "name" => "test", "count" => 42, "active" => true }
      result = resolver.resolve_refs_in(data)
      expect(result).to eq(data)
    end
  end
end
