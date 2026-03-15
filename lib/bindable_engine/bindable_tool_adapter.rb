# frozen_string_literal: true

module BindableEngine
  # Adapts a Bindable instance into MCP-compatible tool definitions and routes
  # tool calls back through the Bindable's uniform interface via ContextRecord.
  #
  # Each implemented Bindable method becomes a separate tool. Tool names follow
  # the convention "bindable_name_action" (e.g., "users_read", "orders_create").
  #
  # When context_bundles are provided, the adapter attaches bundle metadata to
  # tool definitions so LLM orchestrators can assemble context at call time.
  class BindableToolAdapter
    attr_reader :bindable, :context_bundles

    def initialize(bindable, context_bundles: {})
      @bindable = bindable
      @context_bundles = context_bundles
    end

    # Returns an array of tool definition hashes, one per implemented method.
    def tool_definitions
      implemented_methods.map { |action| build_tool_definition(action) }
    end

    # Routes a tool call to the Bindable via ContextRecord.
    # Returns a BindableEngine::Result (Success or Failure).
    def call(tool_name, arguments = {}, metadata: {})
      action = extract_action(tool_name)

      unless action && Bindable::INTERFACE_METHODS.include?(action)
        return Result.failure(
          code: :validation_error,
          message: "Unknown tool: #{tool_name}"
        )
      end

      unless implemented_methods.include?(action)
        return Result.failure(
          code: :not_implemented,
          message: "Action #{action} is not implemented on #{bindable_name}"
        )
      end

      context_record = ContextRecord.new(
        action: action,
        target: bindable_name,
        payload: arguments,
        metadata: metadata
      )

      invoke(context_record)
    end

    private

    def implemented_methods
      @implemented_methods ||= Bindable::INTERFACE_METHODS.select do |method_name|
        next false unless bindable.respond_to?(method_name)

        method_obj = bindable.method(method_name)
        method_obj.owner != Bindable
      end
    end

    def extract_action(tool_name)
      prefix = "#{bindable_name}_"
      return nil unless tool_name.to_s.start_with?(prefix)

      action = tool_name.to_s.delete_prefix(prefix)
      return nil if action.empty?

      action.to_sym
    end

    def build_tool_definition(action)
      description_parts = [bindable_description, method_description_for(action)].compact
      description = description_parts.join(" — ")

      definition = {
        name: "#{bindable_name}_#{action}",
        description: description,
        input_schema: build_input_schema(action),
        _meta: {
          biological: {
            bindable: bindable_name,
            action: action.to_s
          }
        }
      }

      bundle = bundle_for_bindable
      if bundle
        definition[:_meta][:biological][:context_bundle] = bundle[:id]
        definition[:_meta][:biological][:assembly_mode] = bundle[:assembly_mode]
      end

      definition
    end

    def build_input_schema(action)
      schema = {
        type: "object",
        properties: {
          payload: {
            type: "object",
            description: "Data payload for the #{action} action"
          },
          metadata: {
            type: "object",
            description: "Optional metadata (e.g., correlation_id, tenant)"
          }
        },
        required: []
      }

      schema[:required] = ["payload"] if %i[create update].include?(action)

      schema
    end

    def invoke(context_record)
      if bindable.respond_to?(:safe_handle)
        bindable.safe_handle(context_record)
      else
        raw = bindable.handle(context_record)
        normalize_raw_result(raw)
      end
    rescue NotImplementedError => e
      Result.failure(code: :not_implemented, message: e.message)
    rescue StandardError => e
      Result.failure(
        code: :internal_error,
        message: e.message,
        trace: e.backtrace&.first(10)
      )
    end

    def normalize_raw_result(result)
      case result
      when Result
        result
      when Hash
        if result.key?(:error)
          Result.failure(code: :internal_error, message: result[:error].to_s)
        else
          Result.success({ data: result, metadata: {} })
        end
      else
        Result.success({ data: result, metadata: {} })
      end
    end

    def bindable_name
      bindable.class.respond_to?(:bindable_name) ? bindable.class.bindable_name : bindable.class.name
    end

    def bindable_description
      bindable.class.respond_to?(:bindable_description) ? bindable.class.bindable_description : nil
    end

    def method_description_for(action)
      return nil unless bindable.class.respond_to?(:method_descriptions)

      bindable.class.method_descriptions[action]
    end

    def bundle_for_bindable
      context_bundles[bindable_name]
    end
  end
end
