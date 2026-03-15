# frozen_string_literal: true

require "securerandom"

module BindableEngine
  # A self-describing message envelope that carries complete state.
  # Any Service Node can process a ContextRecord without prior context.
  # Implements the REST self-describing messages constraint.
  #
  # Each ContextRecord is a JSON-LD document — @context identifies the
  # vocabulary that gives meaning to the payload fields.
  class ContextRecord
    VV_CONTEXT = "https://verticalvertical.net/ns/biological#"

    attr_reader :id, :action, :target, :payload, :metadata, :timestamp, :context

    VALID_ACTIONS = %i[create read update delete list execute].freeze

    def initialize(action:, target:, payload: {}, metadata: {}, context: nil)
      validate_action!(action)
      @id = SecureRandom.uuid
      @action = action.to_sym
      @target = target.to_s
      @payload = deep_freeze(payload)
      @metadata = deep_freeze(metadata)
      @context = (context || VV_CONTEXT).freeze
      @timestamp = Time.now.utc
    end

    def to_h
      {
        "@context" => @context,
        id: @id,
        action: @action,
        target: @target,
        payload: @payload,
        metadata: @metadata,
        timestamp: @timestamp.iso8601
      }
    end

    def json_ld?
      @context != VV_CONTEXT
    end

    private

    def validate_action!(action)
      return if VALID_ACTIONS.include?(action.to_sym)

      raise BindableEngine::ValidationError,
            "Invalid action '#{action}'. Must be one of: #{VALID_ACTIONS.join(", ")}"
    end

    def deep_freeze(obj)
      case obj
      when Hash then obj.each_with_object({}) { |(k, v), h| h[k] = deep_freeze(v) }.freeze
      when Array then obj.map { |v| deep_freeze(v) }.freeze
      else obj.freeze
      end
    end
  end
end
