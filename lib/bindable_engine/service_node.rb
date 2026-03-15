# frozen_string_literal: true

module BindableEngine
  # The organ. A collection of Bindables operating as an autonomous unit.
  # Each node hosts its own execution environment, its own Moderator,
  # and its own communication gateway. Nodes can be added, removed,
  # specialized, or distributed without architectural compromise.
  class ServiceNode
    attr_reader :name, :moderator

    def initialize(name:, authenticator: nil, authorizer: nil)
      @name = name.to_s
      @moderator = MessageModerator.new(
        node_name: @name,
        authenticator: authenticator,
        authorizer: authorizer
      )
    end

    def register(bindable)
      @moderator.register(bindable)
      BindableRegistry.instance.register(bindable)
      self
    end

    def send_message(context_record)
      @moderator.route(context_record)
    end

    def registered_bindables
      @moderator.registered_bindables
    end

    def log
      @moderator.log
    end
  end
end
