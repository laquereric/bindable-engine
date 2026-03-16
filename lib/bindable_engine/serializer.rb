# frozen_string_literal: true

module BindableEngine
  # JSON-LD serialization helpers for Bindable data.
  # Extracts the recurring @context/@type/@id pattern into reusable methods.
  module Serializer
    module_function

    # Wrap data as a JSON-LD document.
    #
    # @param data [Hash] raw data
    # @param context_url [String] JSON-LD @context URL
    # @param type_name [String] JSON-LD @type value
    # @return [Hash]
    def to_json_ld(data, context_url:, type_name:)
      result = { "@context" => context_url, "@type" => type_name }
      id = data[:id] || data["id"]
      result["@id"] = id.to_s if id
      result.merge(stringify_keys(data))
    end

    # Wrap an array of items as a JSON-LD collection.
    #
    # @param items [Array<Hash>] raw items
    # @param context_url [String]
    # @param type_name [String] singular type name (Collection suffix added)
    # @return [Hash]
    def to_json_ld_collection(items, context_url:, type_name:)
      wrapped = items.map do |item|
        entry = { "@type" => type_name }
        id = item[:id] || item["id"]
        entry["@id"] = id.to_s if id
        entry.merge(stringify_keys(item))
      end

      {
        "@context" => context_url,
        "@type" => "#{type_name}Collection",
        "items" => wrapped,
        "total" => items.size
      }
    end

    # Wrap data as JSON-LD with Refs resolved inline.
    #
    # @param data [Hash]
    # @param context_url [String]
    # @param type_name [String]
    # @param resolver [RefResolver]
    # @return [Hash]
    def to_json_ld_with_refs(data, context_url:, type_name:, resolver:)
      resolved = resolver.resolve_refs_in(data)
      to_json_ld(resolved, context_url: context_url, type_name: type_name)
    end

    def stringify_keys(hash)
      hash.each_with_object({}) do |(k, v), h|
        key = k.to_s
        next if key.start_with?("@")

        h[key] = v
      end
    end
  end
end
