# frozen_string_literal: true

require "singleton"

module BindableEngine
  # Global registry of all Bindable instances.
  # Thread-safe singleton that tracks registered bindables and their
  # implemented methods. Used by ServiceNode#register to auto-register,
  # and by authorization to build capability lists.
  class BindableRegistry
    include Singleton

    def initialize
      @mutex = Mutex.new
      @bindables = {}
    end

    # Register a bindable instance. Discovers which of the 6 interface
    # methods are actually implemented (not just raise NotImplementedError).
    def register(bindable)
      name = bindable.class.respond_to?(:bindable_name) ? bindable.class.bindable_name : bindable.class.name
      methods = discover_methods(bindable)

      @mutex.synchronize do
        @bindables[name] = {
          name: name,
          methods: methods,
          class: bindable.class,
          instance: bindable
        }
      end
      self
    end

    # Returns full manifest of all registered bindables.
    def manifest
      @mutex.synchronize do
        @bindables.values.map do |entry|
          result = { name: entry[:name], methods: entry[:methods], class: entry[:class] }
          if entry[:class].respond_to?(:persistence_config)
            result[:persistence] = entry[:class].persistence_config
          end
          result
        end.freeze
      end
    end

    # Returns manifest filtered by an authorized capability list.
    def filtered_manifest(capability_list)
      cap_map = capability_list.each_with_object({}) do |cap, h|
        h[cap[:name]] = cap[:methods].map(&:to_sym)
      end

      @mutex.synchronize do
        @bindables.values.filter_map do |entry|
          allowed_methods = cap_map[entry[:name]]
          next unless allowed_methods

          intersection = entry[:methods] & allowed_methods
          next if intersection.empty?

          { name: entry[:name], methods: intersection, class: entry[:class] }
        end.freeze
      end
    end

    def names
      @mutex.synchronize { @bindables.keys.freeze }
    end

    def [](name)
      @mutex.synchronize { @bindables[name]&.slice(:name, :methods, :class) }
    end

    def instance_for(name)
      @mutex.synchronize { @bindables[name]&.fetch(:instance) }
    end

    def reset!
      @mutex.synchronize { @bindables.clear }
      self
    end

    def size
      @mutex.synchronize { @bindables.size }
    end

    private

    def discover_methods(bindable)
      Bindable::INTERFACE_METHODS.select do |method_name|
        next false unless bindable.respond_to?(method_name)

        method_obj = bindable.method(method_name)
        method_obj.owner != Bindable
      end
    end
  end
end
