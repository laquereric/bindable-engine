# frozen_string_literal: true

RSpec.describe BindableEngine::Bindable do
  let(:bindable_class) do
    Class.new do
      include BindableEngine::Bindable
      bind_as "TestBindable"

      def create(context_record)
        { created: context_record.payload }
      end

      def read(context_record)
        { id: context_record.payload[:id], name: "test" }
      end

      def list(_context_record)
        [{ id: "1", name: "first" }, { id: "2", name: "second" }]
      end
    end
  end

  let(:bindable) { bindable_class.new }

  describe ".bind_as" do
    it "sets a custom bindable name" do
      expect(bindable_class.bindable_name).to eq("TestBindable")
    end
  end

  describe ".describe_as" do
    it "sets a description" do
      klass = Class.new do
        include BindableEngine::Bindable
        bind_as "Described"
        describe_as "A described bindable"
      end
      expect(klass.bindable_description).to eq("A described bindable")
    end
  end

  describe ".describe_method" do
    it "stores method descriptions" do
      klass = Class.new do
        include BindableEngine::Bindable
        bind_as "WithMethods"
        describe_method :read, "Fetch a record"
      end
      expect(klass.method_descriptions[:read]).to eq("Fetch a record")
    end
  end

  describe "#handle" do
    it "routes create actions" do
      record = BindableEngine::ContextRecord.new(
        action: :create,
        target: "TestBindable",
        payload: { name: "example" }
      )
      result = bindable.handle(record)
      expect(result[:created][:name]).to eq("example")
    end

    it "routes read actions" do
      record = BindableEngine::ContextRecord.new(
        action: :read,
        target: "TestBindable",
        payload: { id: "123" }
      )
      result = bindable.handle(record)
      expect(result[:id]).to eq("123")
    end

    it "raises NotImplementedError for unimplemented methods" do
      record = BindableEngine::ContextRecord.new(
        action: :delete,
        target: "TestBindable",
        payload: { id: "123" }
      )
      expect { bindable.handle(record) }.to raise_error(NotImplementedError)
    end

    it "raises ValidationError for unknown actions" do
      record = BindableEngine::ContextRecord.new(action: :list, target: "TestBindable")
      allow(record).to receive(:action).and_return(:explode)
      expect { bindable.handle(record) }.to raise_error(BindableEngine::ValidationError)
    end
  end

  describe "uniform interface" do
    it "defines exactly six interface methods" do
      expect(BindableEngine::Bindable::INTERFACE_METHODS).to eq(
        %i[create read update delete list execute]
      )
    end
  end
end
