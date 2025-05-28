# frozen_string_literal: true

module RubyLLM
  # Server-side web search tool that leverages the provider's built-in web search capabilities.
  # This tool is executed by the AI provider (like OpenAI or Anthropic) rather than locally.
  #
  # Different providers implement web search differently:
  # - OpenAI: Uses web_search_options in the request payload with search-enabled models
  # - Anthropic: Uses the web_search_20250305 tool type
  #
  # Example:
  #   chat = RubyLLM.chat(model: 'gpt-4o-search-preview')
  #   chat.with_tool(RubyLLM::WebSearchTool.new)
  #   response = chat.ask("What's the latest news about Ruby programming language?")
  class WebSearchTool < ServerTool
    def initialize(max_uses: 10, config: {})
      # Different providers use different type identifiers for web search
      provider_types = {
        openai: 'web_search',
        anthropic: 'web_search_20250305'
      }
      
      super(
        type: 'web_search', # Default type, will be overridden per provider
        name: 'web_search',
        max_uses: max_uses,
        supported_providers: [:openai, :anthropic],
        config: config.merge(provider_types: provider_types)
      )
    end
    
    # Get the appropriate type identifier for a specific provider
    def type_for(provider)
      provider_slug = provider.respond_to?(:slug) ? provider.slug.to_sym : provider.to_sym
      config[:provider_types][provider_slug] || type
    end
    
    # Override to provide more specific validation
    def validate_model_compatibility(model, provider)
      super
      
      # For OpenAI, check if the model supports web search
      if provider.slug.to_sym == :openai && !provider.capabilities.supports_web_search?(model.id)
        raise UnsupportedFunctionsError,
              "Model '#{model.id}' doesn't support web search. Use a search-enabled model like 'gpt-4o-search-preview'"
      end
      
      true
    end
  end
end 