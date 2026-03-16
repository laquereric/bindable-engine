# frozen_string_literal: true

module BindableEngine
  # Cross-domain reference — a pointer resolved lazily through Bindable#read.
  # Frozen value object usable as a hash key.
  class Ref
    attr_reader :target, :id, :label

    def initialize(target:, id:, label: nil)
      @target = target.to_s.freeze
      @id = id.to_s.freeze
      @label = label&.to_s&.freeze
      freeze
    end

    def to_h
      h = { "@type" => "Ref", "target" => @target, "id" => @id }
      h["label"] = @label if @label
      h
    end

    def ==(other)
      other.is_a?(Ref) && @target == other.target && @id == other.id
    end

    alias eql? ==

    def hash
      [@target, @id].hash
    end

    def inspect
      "#<BindableEngine::Ref target=#{@target.inspect} id=#{@id.inspect}>"
    end
  end
end
