# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Streaming methods of the OpenAI API integration
      module Streaming
        module_function

        def stream_url
          completion_url
        end

        def build_chunk(data)
          # Extract content which may include web search results
          content = extract_streaming_content(data)
          
          Chunk.new(
            role: :assistant,
            model_id: data['model'],
            content: content,
            tool_calls: parse_tool_calls(data.dig('choices', 0, 'delta', 'tool_calls'), parse_arguments: false),
            input_tokens: data.dig('usage', 'prompt_tokens'),
            output_tokens: data.dig('usage', 'completion_tokens')
          )
        end

        def extract_streaming_content(data)
          delta = data.dig('choices', 0, 'delta')
          return nil unless delta
          
          # Regular content
          content = delta['content']
          
          # Check for web search results in the delta
          # This is a placeholder - actual format depends on OpenAI's streaming response structure
          if delta['search_results']
            # Handle search results if they come through streaming
            content
          else
            content
          end
        end
      end
    end
  end
end
