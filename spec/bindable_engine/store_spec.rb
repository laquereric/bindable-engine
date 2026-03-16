# frozen_string_literal: true

RSpec.describe BindableEngine::Store do
  subject(:store) { described_class.new }

  describe "#save" do
    it "raises NotImplementedError" do
      expect { store.save("1", {}) }.to raise_error(NotImplementedError)
    end
  end

  describe "#find" do
    it "raises NotImplementedError" do
      expect { store.find("1") }.to raise_error(NotImplementedError)
    end
  end

  describe "#query" do
    it "raises NotImplementedError" do
      expect { store.query }.to raise_error(NotImplementedError)
    end
  end

  describe "#destroy" do
    it "raises NotImplementedError" do
      expect { store.destroy("1") }.to raise_error(NotImplementedError)
    end
  end

  describe "#serialize" do
    it "delegates to Serializer.to_json_ld" do
      result = store.serialize({ "id" => "1", "name" => "Test" },
                               context_url: "https://example.com/ns",
                               type_name: "Thing")
      expect(result["@context"]).to eq("https://example.com/ns")
      expect(result["@type"]).to eq("Thing")
      expect(result["@id"]).to eq("1")
      expect(result["name"]).to eq("Test")
    end
  end
end
