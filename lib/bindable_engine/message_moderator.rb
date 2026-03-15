# frozen_string_literal: true

module BindableEngine
  # The cell membrane. Every message entering or leaving a Service Node
  # passes through its Moderator. It authenticates, authorizes, routes,
  # and logs — but does not direct.
  #
  # Infrastructure, not intelligence. Messages pass through it, not from it.
  class MessageModerator
    attr_reader :node_name, :log

    def initialize(node_name:, authenticator: nil, authorizer: nil)
      @node_name = node_name.to_s
      @authenticator = authenticator || ->(_record) { true }
      @authorizer = authorizer || ->(_record) { true }
      @log = []
      @bindables = {}
    end

    def register(bindable)
      name = bindable.class.respond_to?(:bindable_name) ? bindable.class.bindable_name : bindable.class.name
      @bindables[name] = bindable
      self
    end

    def route(context_record)
      entry = log_entry(context_record, :received)

      authenticate!(context_record)
      authorize!(context_record)

      bindable = resolve_target(context_record.target)
      result = if bindable.respond_to?(:safe_handle)
                 bindable.safe_handle(context_record)
               else
                 bindable.handle(context_record)
               end

      entry[:status] = :completed
      entry[:completed_at] = Time.now.utc
      result
    rescue AuthenticationError => e
      entry[:status] = :failed
      entry[:error] = e.message
      entry[:completed_at] = Time.now.utc
      Result.failure(code: :unauthorized, message: e.message)
    rescue AuthorizationError => e
      entry[:status] = :failed
      entry[:error] = e.message
      entry[:completed_at] = Time.now.utc
      Result.failure(code: :forbidden, message: e.message)
    rescue Error => e
      entry[:status] = :failed
      entry[:error] = e.message
      entry[:completed_at] = Time.now.utc
      Result.failure(code: :not_found, message: e.message)
    rescue StandardError => e
      entry[:status] = :failed
      entry[:error] = e.message
      entry[:completed_at] = Time.now.utc
      Result.failure(code: :internal_error, message: e.message)
    end

    def registered_bindables
      @bindables.keys.freeze
    end

    private

    def authenticate!(context_record)
      return if @authenticator.call(context_record)

      raise AuthenticationError, "Authentication failed for message #{context_record.id}"
    end

    def authorize!(context_record)
      return if @authorizer.call(context_record)

      raise AuthorizationError, "Authorization failed for #{context_record.action} on #{context_record.target}"
    end

    def resolve_target(target)
      @bindables[target] or raise Error, "No bindable registered for target '#{target}'"
    end

    def log_entry(context_record, status)
      entry = {
        message_id: context_record.id,
        action: context_record.action,
        target: context_record.target,
        node: @node_name,
        status: status,
        received_at: Time.now.utc
      }
      @log << entry
      entry
    end
  end
end
