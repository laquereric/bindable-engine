# frozen_string_literal: true

RSpec.describe BindableEngine::BindableRegistry do
  let(:registry) { described_class.instance }

  let(:users_class) do
    Class.new do
      include BindableEngine::Bindable
      bind_as "users"

      def read(_ctx)
        {}
      end

      def list(_ctx)
        []
      end
    end
  end

  let(:orders_class) do
    Class.new do
      include BindableEngine::Bindable
      bind_as "orders"

      def create(_ctx)
        {}
      end

      def read(_ctx)
        {}
      end

      def list(_ctx)
        []
      end
    end
  end

  before { registry.reset! }

  describe "#register" do
    it "registers a bindable" do
      registry.register(users_class.new)
      expect(registry.size).to eq(1)
    end

    it "discovers implemented methods" do
      registry.register(users_class.new)
      entry = registry["users"]
      expect(entry[:methods]).to contain_exactly(:read, :list)
    end

    it "returns self for chaining" do
      result = registry.register(users_class.new)
      expect(result).to eq(registry)
    end
  end

  describe "#manifest" do
    before do
      registry.register(users_class.new)
      registry.register(orders_class.new)
    end

    it "returns all registered bindables" do
      expect(registry.manifest.size).to eq(2)
    end

    it "includes name, methods, and class" do
      entry = registry.manifest.find { |e| e[:name] == "users" }
      expect(entry[:methods]).to contain_exactly(:read, :list)
      expect(entry[:class]).to eq(users_class)
    end
  end

  describe "#filtered_manifest" do
    before do
      registry.register(users_class.new)
      registry.register(orders_class.new)
    end

    it "returns only allowed bindables and methods" do
      capability_list = [{ name: "users", methods: [:read] }]
      filtered = registry.filtered_manifest(capability_list)
      expect(filtered.size).to eq(1)
      expect(filtered.first[:name]).to eq("users")
      expect(filtered.first[:methods]).to eq([:read])
    end

    it "excludes bindables not in capability list" do
      capability_list = [{ name: "users", methods: [:read] }]
      filtered = registry.filtered_manifest(capability_list)
      names = filtered.map { |e| e[:name] }
      expect(names).not_to include("orders")
    end

    it "excludes bindables with no method overlap" do
      capability_list = [{ name: "users", methods: [:create] }]
      filtered = registry.filtered_manifest(capability_list)
      expect(filtered).to be_empty
    end
  end

  describe "#names" do
    it "returns all registered names" do
      registry.register(users_class.new)
      registry.register(orders_class.new)
      expect(registry.names).to contain_exactly("users", "orders")
    end
  end

  describe "#instance_for" do
    it "returns the bindable instance" do
      instance = users_class.new
      registry.register(instance)
      expect(registry.instance_for("users")).to eq(instance)
    end

    it "returns nil for unknown names" do
      expect(registry.instance_for("nonexistent")).to be_nil
    end
  end

  describe "#reset!" do
    it "clears all registrations" do
      registry.register(users_class.new)
      registry.reset!
      expect(registry.size).to eq(0)
    end
  end
end
