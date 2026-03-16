# frozen_string_literal: true

module BindableEngine
  # Standalone Success/Failure Result monad.
  #
  # Replaces LibraryException::Result (Dry::Monads) with a zero-dependency
  # implementation. Error codes follow the MCP-BINDABLE spec (§8):
  #
  #   :unauthorized, :forbidden, :not_found, :validation_error,
  #   :not_implemented, :internal_error
  #
  # Usage:
  #   Result.success({ id: "42", name: "Alice" })
  #   Result.success({ id: "42" }, metadata: { control: "CC1.1" })
  #   Result.failure(code: :not_found, message: "User not found")
  #
  class Result
    attr_reader :value, :error

    def self.success(value, metadata: nil)
      wrapped = if metadata
                  { data: value, metadata: metadata }
                else
                  value
                end
      new(success: true, value: wrapped)
    end

    def self.failure(code:, message:, **extra)
      error = { code: code, message: message }.merge(extra)
      new(success: false, error: error)
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    # Unwraps the success value. Raises on Failure.
    def value!
      raise "Cannot unwrap a Failure: #{@error}" if failure?

      @value
    end

    # Returns the failure hash. Returns nil on Success.
    def failure
      @error
    end

    # Transforms the success value. Returns self on Failure.
    def map
      return self if failure?

      self.class.success(yield(@value))
    end

    # Chains Result-returning operations. Returns self on Failure.
    def bind
      return self if failure?

      yield(@value)
    end

    private

    def initialize(success:, value: nil, error: nil)
      @success = success
      @value = value
      @error = error
      freeze
    end
  end
end
