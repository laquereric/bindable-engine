# frozen_string_literal: true

RSpec.describe BindableEngine::BindableToolAdapter do
  # Full bindable: implements all 6 methods with DSL descriptions
  let(:full_bindable_class) do
    Class.new do
      include BindableEngine::Bindable
      include BindableEngine::BindableResultWrapper
      bind_as "users"
      describe_as "User management"
      describe_method :create, "Create a new user"
      describe_method :read, "Retrieve a user by ID"
      describe_method :update, "Update user attributes"
      describe_method :delete, "Delete a user"
      describe_method :list, "List all users"
      describe_method :execute, "Run a user action"

      def create(context_record)
        { id: "u-001", name: context_record.payload[:name] }
      end

      def read(context_record)
        { id: context_record.payload[:id], name: "Alice" }
      end

      def update(context_record)
        { id: context_record.payload[:id], updated: true }
      end

      def delete(context_record)
        { id: context_record.payload[:id], deleted: true }
      end

      def list(_context_record)
        [{ id: "u-001", name: "Alice" }, { id: "u-002", name: "Bob" }]
      end

      def execute(context_record)
        { action: context_record.payload[:action], result: "done" }
      end
    end
  end

  # Partial bindable: implements only read + list
  let(:partial_bindable_class) do
    Class.new do
      include BindableEngine::Bindable
      include BindableEngine::BindableResultWrapper
      bind_as "articles"
      describe_as "Article catalog"
      describe_method :read, "Fetch an article"
      describe_method :list, "Browse articles"

      def read(context_record)
        { id: context_record.payload[:id], title: "Hello World" }
      end

      def list(_context_record)
        [{ id: "a-001", title: "Hello World" }]
      end
    end
  end

  # Bindable without BindableResultWrapper — raw return values
  let(:raw_bindable_class) do
    Class.new do
      include BindableEngine::Bindable
      bind_as "raw_items"
      describe_as "Raw items store"

      def read(context_record)
        { id: context_record.payload[:id], raw: true }
      end

      def create(_context_record)
        { error: "something broke" }
      end
    end
  end

  let(:full_bindable) { full_bindable_class.new }
  let(:partial_bindable) { partial_bindable_class.new }
  let(:raw_bindable) { raw_bindable_class.new }

  let(:context_bundles) do
    {
      "users" => { id: "user-ctx-bundle", assembly_mode: "parallel", views: [{ name: "profile" }] }
    }
  end

  let(:adapter) { described_class.new(full_bindable) }
  let(:adapter_with_bundles) { described_class.new(full_bindable, context_bundles: context_bundles) }
  let(:partial_adapter) { described_class.new(partial_bindable) }
  let(:raw_adapter) { described_class.new(raw_bindable) }

  describe "#initialize" do
    it "stores the bindable instance" do
      expect(adapter.bindable).to eq(full_bindable)
    end

    it "defaults context_bundles to empty hash" do
      expect(adapter.context_bundles).to eq({})
    end

    it "accepts context_bundles" do
      expect(adapter_with_bundles.context_bundles).to eq(context_bundles)
    end
  end

  describe "#tool_definitions" do
    context "with a full bindable (all 6 methods)" do
      let(:definitions) { adapter.tool_definitions }

      it "returns one definition per implemented method" do
        expect(definitions.size).to eq(6)
      end

      it "generates tool names using bindable_name + action" do
        names = definitions.map { |d| d[:name] }
        expect(names).to contain_exactly(
          "users_create", "users_read", "users_update",
          "users_delete", "users_list", "users_execute"
        )
      end

      it "composes description from bindable description and method description" do
        read_def = definitions.find { |d| d[:name] == "users_read" }
        expect(read_def[:description]).to eq("User management — Retrieve a user by ID")
      end

      it "includes input_schema with type object" do
        read_def = definitions.find { |d| d[:name] == "users_read" }
        expect(read_def[:input_schema][:type]).to eq("object")
        expect(read_def[:input_schema][:properties]).to have_key(:payload)
        expect(read_def[:input_schema][:properties]).to have_key(:metadata)
      end

      it "requires payload for create and update actions" do
        create_def = definitions.find { |d| d[:name] == "users_create" }
        update_def = definitions.find { |d| d[:name] == "users_update" }
        read_def = definitions.find { |d| d[:name] == "users_read" }

        expect(create_def[:input_schema][:required]).to eq(["payload"])
        expect(update_def[:input_schema][:required]).to eq(["payload"])
        expect(read_def[:input_schema][:required]).to eq([])
      end

      it "includes _meta.biological with bindable and action" do
        read_def = definitions.find { |d| d[:name] == "users_read" }
        meta = read_def[:_meta][:biological]
        expect(meta[:bindable]).to eq("users")
        expect(meta[:action]).to eq("read")
      end
    end

    context "with a partial bindable (read + list only)" do
      let(:definitions) { partial_adapter.tool_definitions }

      it "returns only definitions for implemented methods" do
        expect(definitions.size).to eq(2)
      end

      it "generates names for implemented methods only" do
        names = definitions.map { |d| d[:name] }
        expect(names).to contain_exactly("articles_read", "articles_list")
      end
    end

    context "with context_bundles provided" do
      let(:definitions) { adapter_with_bundles.tool_definitions }

      it "attaches context_bundle id to _meta.biological" do
        read_def = definitions.find { |d| d[:name] == "users_read" }
        expect(read_def[:_meta][:biological][:context_bundle]).to eq("user-ctx-bundle")
      end

      it "attaches assembly_mode to _meta.biological" do
        read_def = definitions.find { |d| d[:name] == "users_read" }
        expect(read_def[:_meta][:biological][:assembly_mode]).to eq("parallel")
      end
    end

    context "without context_bundles" do
      let(:definitions) { adapter.tool_definitions }

      it "omits context_bundle and assembly_mode from _meta" do
        read_def = definitions.find { |d| d[:name] == "users_read" }
        expect(read_def[:_meta][:biological]).not_to have_key(:context_bundle)
        expect(read_def[:_meta][:biological]).not_to have_key(:assembly_mode)
      end
    end

    context "description composition" do
      it "uses only bindable description when no method description exists" do
        no_method_desc_class = Class.new do
          include BindableEngine::Bindable
          bind_as "widgets"
          describe_as "Widget management"

          def read(_ctx)
            {}
          end
        end
        adapter = described_class.new(no_method_desc_class.new)
        definitions = adapter.tool_definitions
        read_def = definitions.find { |d| d[:name] == "widgets_read" }
        expect(read_def[:description]).to eq("Widget management")
      end

      it "returns empty string description when neither is set" do
        bare_class = Class.new do
          include BindableEngine::Bindable
          bind_as "bare"

          def read(_ctx)
            {}
          end
        end
        adapter = described_class.new(bare_class.new)
        definitions = adapter.tool_definitions
        read_def = definitions.find { |d| d[:name] == "bare_read" }
        expect(read_def[:description]).to eq("")
      end
    end
  end

  describe "#call" do
    context "with a valid tool name and arguments" do
      it "creates a ContextRecord and returns a Success result" do
        result = adapter.call("users_read", { id: "u-001" })
        expect(result.success?).to be true
        expect(result.value![:data][:id]).to eq("u-001")
        expect(result.value![:data][:name]).to eq("Alice")
      end

      it "passes payload through to the bindable" do
        result = adapter.call("users_create", { name: "Charlie" })
        expect(result.success?).to be true
        expect(result.value![:data][:name]).to eq("Charlie")
      end

      it "passes metadata through to the ContextRecord" do
        result = adapter.call("users_read", { id: "u-001" }, metadata: { tenant: "acme" })
        expect(result.success?).to be true
        expect(result.value![:data][:id]).to eq("u-001")
      end
    end

    context "with an unknown tool name" do
      it "returns a validation_error Failure" do
        result = adapter.call("unknown_tool", {})
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:validation_error)
        expect(result.failure[:message]).to include("Unknown tool")
      end
    end

    context "with a wrong bindable prefix" do
      it "returns a validation_error Failure" do
        result = adapter.call("orders_read", {})
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:validation_error)
      end
    end

    context "with an unimplemented action" do
      it "returns a not_implemented Failure" do
        result = partial_adapter.call("articles_create", { title: "Test" })
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:not_implemented)
        expect(result.failure[:message]).to include("not implemented")
      end
    end

    context "with empty arguments" do
      it "passes empty payload through successfully" do
        result = adapter.call("users_list")
        expect(result.success?).to be true
        expect(result.value![:data]).to be_an(Array)
        expect(result.value![:data].size).to eq(2)
      end
    end

    context "result normalization with BindableResultWrapper" do
      it "wraps hash returns in Success" do
        result = adapter.call("users_read", { id: "u-001" })
        expect(result.success?).to be true
        expect(result.value!).to have_key(:data)
        expect(result.value!).to have_key(:metadata)
      end

      it "wraps array returns in Success" do
        result = adapter.call("users_list")
        expect(result.success?).to be true
        expect(result.value![:data]).to be_an(Array)
      end
    end

    context "result normalization without BindableResultWrapper (raw bindable)" do
      it "normalizes hash returns into Success" do
        result = raw_adapter.call("raw_items_read", { id: "item-1" })
        expect(result.success?).to be true
        expect(result.value![:data][:id]).to eq("item-1")
        expect(result.value![:data][:raw]).to eq(true)
      end

      it "normalizes error hashes into Failure" do
        result = raw_adapter.call("raw_items_create", {})
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:internal_error)
        expect(result.failure[:message]).to eq("something broke")
      end
    end

    context "when the bindable raises an exception" do
      let(:error_bindable_class) do
        Class.new do
          include BindableEngine::Bindable
          bind_as "crasher"

          def read(_ctx)
            raise StandardError, "kaboom"
          end
        end
      end

      let(:error_adapter) { described_class.new(error_bindable_class.new) }

      it "catches exceptions and returns internal_error Failure" do
        result = error_adapter.call("crasher_read", {})
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:internal_error)
        expect(result.failure[:message]).to eq("kaboom")
        expect(result.failure[:trace]).to be_an(Array)
      end
    end
  end
end
