# frozen_string_literal: true

module BindableEngine
  # Assembles context bundles by calling multiple Bindables and merging their
  # results. Used by the LLM context layer to build rich context from multiple
  # data sources at journey interaction points.
  #
  # Supports three assembly modes:
  #   - parallel:   Fetch all views independently, merge results
  #   - sequential: Fetch in order, each view receives accumulated context
  #   - lazy:       Return view specs without fetching (caller resolves later)
  #
  # Graceful on failures: failed views are skipped, successful ones included.
  class ContextAssembler
    def initialize(registry:)
      @registry = registry
    end

    # Assemble a context bundle by calling multiple Bindables.
    #
    # bundle_definition format:
    # {
    #   id: "user-profile-context",
    #   assembly_mode: "parallel",
    #   views: [
    #     { concept: "users", fields: [:id, :email, :name] },
    #     { concept: "profiles", includes: { presets: [:name, :temperature] } }
    #   ]
    # }
    #
    # Returns a hash:
    # { bundle: id, assembly_mode: mode, views: { concept => filtered_data } }
    def assemble(bundle_definition, actor_metadata: {})
      id = bundle_definition[:id]
      mode = (bundle_definition[:assembly_mode] || "parallel").to_s
      views = bundle_definition[:views] || []

      assembled_views = case mode
                        when "sequential"
                          assemble_sequential(views, actor_metadata)
                        when "lazy"
                          assemble_lazy(views, actor_metadata)
                        else
                          assemble_parallel(views, actor_metadata)
                        end

      {
        bundle: id,
        assembly_mode: mode,
        views: assembled_views
      }
    end

    private

    def assemble_parallel(views, actor_metadata)
      results = {}

      views.each do |view|
        concept = view[:concept]
        next unless concept

        data = fetch_view(view, actor_metadata)
        results[concept] = data unless data.nil?
      end

      results
    end

    def assemble_sequential(views, actor_metadata)
      results = {}
      accumulated = {}

      views.each do |view|
        concept = view[:concept]
        next unless concept

        enriched_metadata = actor_metadata.merge(accumulated_context: accumulated)
        data = fetch_view(view, enriched_metadata)

        unless data.nil?
          results[concept] = data
          accumulated[concept] = data
        end
      end

      results
    end

    def assemble_lazy(views, _actor_metadata)
      results = {}

      views.each do |view|
        concept = view[:concept]
        next unless concept

        results[concept] = {
          _lazy: true,
          concept: concept,
          fields: view[:fields],
          includes: view[:includes]
        }.compact
      end

      results
    end

    def fetch_view(view, actor_metadata)
      concept = view[:concept]
      bindable = @registry.instance_for(concept)
      return nil unless bindable
      return nil unless bindable.respond_to?(:safe_handle)

      action = view[:action] || :read
      record = ContextRecord.new(
        action: action,
        target: concept,
        payload: view[:payload] || {},
        metadata: actor_metadata
      )

      result = bindable.safe_handle(record)
      return nil unless result.is_a?(Result) && result.success?

      data = result.value![:data]
      data = filter_fields(data, view[:fields]) if view[:fields]
      data = expand_includes(data, view[:includes]) if view[:includes]
      data
    end

    def filter_fields(data, fields)
      case data
      when Hash
        data.select { |key, _| fields.include?(key) }
      when Array
        data.map { |item| item.is_a?(Hash) ? item.select { |key, _| fields.include?(key) } : item }
      else
        data
      end
    end

    def expand_includes(data, includes)
      return data unless data.is_a?(Hash)

      expanded = data.dup
      includes.each do |association, fields|
        assoc_data = data[association]
        next unless assoc_data

        expanded[association] = filter_fields(assoc_data, fields)
      end
      expanded
    end
  end
end
