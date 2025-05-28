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
    attr_reader :type, :name, :max_uses, :supported_providers, :config

    def initialize(type:, name:, max_uses: 10, supported_providers: nil, config: {})
      @type = type
      @name = name
      @max_uses = max_uses
      @supported_providers = supported_providers || [:openai, :anthropic]
      @config = config
    end

    def client_tool?
      false
    end

    def server_tool?
      true
    end

    # Check if this server tool is supported by a specific provider
    def supported_by?(provider)
      provider_slug = provider.respond_to?(:slug) ? provider.slug.to_sym : provider.to_sym
      supported_providers.include?(provider_slug)
    end

    # Get provider-specific configuration
    def config_for(provider)
      provider_slug = provider.respond_to?(:slug) ? provider.slug.to_sym : provider.to_sym
      config[provider_slug] || {}
    end

    # Server tools don't have local execution - they're handled by the provider
    def call(args)
      raise NotImplementedError, 'Server tools are executed by the provider, not locally'
    end

    def execute(...)
      raise NotImplementedError, 'Server tools are executed by the provider, not locally'
    end

    # Validation method to check if the tool can be used with a specific model
    def validate_model_compatibility(model, provider)
      unless supported_by?(provider)
        raise UnsupportedFunctionsError, 
              "Server tool '#{name}' is not supported by provider '#{provider.slug}'"
      end

      # Additional model-specific validation can be added here
      true
    end
  end
end 