# frozen_string_literal: true

module BindableEngine
  # Abstract store interface for Bindable persistence.
  # All methods return BindableEngine::Result.
  #
  # Concrete implementations:
  #   - BindableEngine::Stores::MemoryStore (this gem)
  #   - BindableEngineRails::Stores::RelationalStore (bindable-engine-rails)
  #   - BindableOntology::Stores::GraphStoreAdapter (bindable-ontology)
  class Store
    def save(id, attrs)
      raise NotImplementedError, "#{self.class}#save not implemented"
    end

    def find(id)
      raise NotImplementedError, "#{self.class}#find not implemented"
    end

    def query(criteria = {})
      raise NotImplementedError, "#{self.class}#query not implemented"
    end

    def destroy(id)
      raise NotImplementedError, "#{self.class}#destroy not implemented"
    end

    def serialize(record, context_url:, type_name:)
      Serializer.to_json_ld(record, context_url: context_url, type_name: type_name)
    end
  end
end
