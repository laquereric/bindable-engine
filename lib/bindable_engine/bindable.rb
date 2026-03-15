# frozen_string_literal: true

module BindableEngine
  # The cell. Autonomous component exposing exactly six methods — the uniform
  # interface that makes everything else possible.
  #
  # Include this module in any class to make it a Bindable component.
  # All communication between Bindables passes through the Message Moderator;
  # data passes by value, never by reference.
  module Bindable
    INTERFACE_METHODS = %i[create read update delete list execute].freeze

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def bindable_name
        @bindable_name || name
      end

      def bind_as(name)
        @bindable_name = name.to_s
      end

      def describe_as(description)
        @bindable_description = description.to_s
      end

      def bindable_description
        @bindable_description
      end

      def describe_method(method_name, description)
        @method_descriptions ||= {}
        @method_descriptions[method_name.to_sym] = description.to_s
      end

      def method_descriptions
        @method_descriptions || {}
      end
    end

    def create(context_record)
      raise NotImplementedError, "#{self.class}#create not implemented"
    end

    def read(context_record)
      raise NotImplementedError, "#{self.class}#read not implemented"
    end

    def update(context_record)
      raise NotImplementedError, "#{self.class}#update not implemented"
    end

    def delete(context_record)
      raise NotImplementedError, "#{self.class}#delete not implemented"
    end

    def list(context_record)
      raise NotImplementedError, "#{self.class}#list not implemented"
    end

    def execute(context_record)
      raise NotImplementedError, "#{self.class}#execute not implemented"
    end

    def handle(context_record)
      action = context_record.action
      unless INTERFACE_METHODS.include?(action)
        raise BindableEngine::ValidationError, "Unknown action: #{action}"
      end

      send(action, context_record)
    end
  end
end
