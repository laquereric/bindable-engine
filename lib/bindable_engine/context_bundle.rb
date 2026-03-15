# frozen_string_literal: true

module BindableEngine
  # Immutable value object representing a context bundle definition.
  # Bundles declare what context an LLM needs at a specific interaction point.
  #
  # Three assembly modes:
  #   - parallel:   Fetch all views independently, merge results
  #   - sequential: Fetch in order, each view receives accumulated context
  #   - lazy:       Return view specs without fetching (caller resolves later)
  class ContextBundle
    VALID_MODES = %w[parallel sequential lazy].freeze

    attr_reader :id, :assembly_mode, :views

    def initialize(id:, assembly_mode: "parallel", views: [])
      @id = id.to_s.freeze
      @assembly_mode = validate_mode!(assembly_mode)
      @views = views.map(&:freeze).freeze
      freeze
    end

    def to_h
      {
        id: @id,
        assembly_mode: @assembly_mode,
        views: @views
      }
    end

    private

    def validate_mode!(mode)
      mode = mode.to_s
      unless VALID_MODES.include?(mode)
        raise BindableEngine::ValidationError,
              "Invalid assembly_mode '#{mode}'. Must be one of: #{VALID_MODES.join(", ")}"
      end
      mode.freeze
    end
  end
end
