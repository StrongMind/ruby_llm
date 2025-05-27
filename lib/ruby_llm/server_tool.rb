# frozen_string_literal: true

module RubyLLM
  # Base class for creating server-side tools that are executed by the AI provider
  # rather than locally. These tools are sent to the provider as part of the request
  # and the provider handles their execution.
  #
  # Example:
  #   class WebSearchTool < RubyLLM::ServerTool
  #     def initialize
  #       super(type: 'web_search', name: 'web_search')
  #     end
  #   end
  class ServerTool
    attr_reader :type, :name, :max_uses

    def initialize(type:, name:, max_uses: 10)
      @type = type
      @name = name
      @max_uses = max_uses
    end

    def client_tool?
      false
    end

    def server_tool?
      true
    end

    # Server tools don't have local execution - they're handled by the provider
    def call(args)
      raise NotImplementedError, 'Server tools are executed by the provider, not locally'
    end

    def execute(...)
      raise NotImplementedError, 'Server tools are executed by the provider, not locally'
    end
  end
end 