# frozen_string_literal: true

module BindableEngine
  # Wraps every Bindable method call through safe_handle(), normalizing return
  # values to Result monads and catching exceptions. Include alongside
  # Bindable in concrete implementations:
  #
  #   class LocationBindable
  #     include BindableEngine::Bindable
  #     include BindableEngine::BindableResultWrapper
  #   end
  #
  # All results are BindableEngine::Result (Success/Failure).
  module BindableResultWrapper
    def safe_handle(context_record)
      action = context_record.action.to_sym
      unless Bindable::INTERFACE_METHODS.include?(action)
        return Result.failure(
          code: :validation_error,
          message: "Unknown action: #{action}"
        )
      end

      raw = send(action, context_record)
      normalize_result(raw)
    rescue BindableEngine::ValidationError => e
      Result.failure(code: :validation_error, message: e.message)
    rescue BindableEngine::AuthenticationError => e
      Result.failure(code: :unauthorized, message: e.message)
    rescue BindableEngine::AuthorizationError => e
      Result.failure(code: :forbidden, message: e.message)
    rescue NotImplementedError => e
      Result.failure(code: :not_implemented, message: e.message)
    rescue StandardError => e
      report_exception(e, context_record)
      Result.failure(
        code: :internal_error,
        message: e.message,
        trace: e.backtrace&.first(10)
      )
    end

    private

    def normalize_result(result)
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

    def report_exception(exception, context_record)
      # Override in concrete bindables to delegate to an exception reporter
    end
  end
end
