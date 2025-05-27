# frozen_string_literal: true

module RubyLLM
  # Server-side web search tool that leverages the provider's built-in web search capabilities.
  # This tool is executed by the AI provider (like Anthropic) rather than locally.
  #
  # Example:
  #   chat = RubyLLM.chat(model: 'claude-3-5-sonnet-20241022', provider: :bedrock)
  #   chat.with_tool(RubyLLM::WebSearchTool.new)
  #   response = chat.ask("What's the latest news about Ruby programming language?")
  class WebSearchTool < ServerTool
    def initialize(max_uses: 10)
      super(type: 'web_search_20250305', name: 'web_search', max_uses: max_uses)
    end
  end
end 