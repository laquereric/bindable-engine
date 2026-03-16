# frozen_string_literal: true

module BindableEngine
  # Resolves Refs through BindableRegistry — looks up the target Bindable
  # and calls read() to fetch the referenced data.
  class RefResolver
    MAX_DEPTH = 3

    def initialize(registry: BindableRegistry.instance)
      @registry = registry
    end

    # Resolve a single Ref.
    #
    # @param ref [Ref]
    # @return [Result]
    def resolve(ref)
      bindable = @registry.instance_for(ref.target)
      unless bindable
        return Result.failure(
          code: :not_found,
          message: "No bindable registered for target: #{ref.target}"
        )
      end

      context_record = ContextRecord.new(
        action: :read,
        target: ref.target,
        payload: { id: ref.id }
      )
      result = bindable.read(context_record)

      if result.is_a?(Result)
        result
      else
        Result.success(result)
      end
    end

    # Resolve multiple Refs, returning a map of Ref => Result.
    #
    # @param refs [Array<Ref>]
    # @return [Hash{Ref => Result}]
    def resolve_all(refs)
      refs.each_with_object({}) { |ref, map| map[ref] = resolve(ref) }
    end

    # Walk a data structure, replacing Ref objects with resolved data.
    # Failed resolutions degrade to Ref#to_h.
    #
    # @param data [Hash, Array, Object]
    # @param depth [Integer] current recursion depth
    # @return [Hash, Array, Object]
    def resolve_refs_in(data, depth: 0)
      return data if depth >= MAX_DEPTH

      case data
      when Ref
        result = resolve(data)
        result.success? ? result.value! : data.to_h
      when Hash
        data.each_with_object({}) do |(key, value), h|
          h[key] = resolve_refs_in(value, depth: depth + 1)
        end
      when Array
        data.map { |item| resolve_refs_in(item, depth: depth + 1) }
      else
        data
      end
    end
  end
end
