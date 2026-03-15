# frozen_string_literal: true

require_relative "bindable_engine/version"
require_relative "bindable_engine/result"
require_relative "bindable_engine/context_record"
require_relative "bindable_engine/bindable"
require_relative "bindable_engine/bindable_result_wrapper"
require_relative "bindable_engine/bindable_registry"
require_relative "bindable_engine/bindable_tool_adapter"
require_relative "bindable_engine/context_bundle"
require_relative "bindable_engine/context_assembler"
require_relative "bindable_engine/message_moderator"
require_relative "bindable_engine/service_node"

module BindableEngine
  class Error < StandardError; end
  class ValidationError < Error; end
  class AuthenticationError < Error; end
  class AuthorizationError < Error; end
end
