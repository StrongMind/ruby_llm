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
          # Handle new semantic events format from Responses API
          case data['type']
          when 'response.created'
            build_response_created_chunk(data)
          # when 'response.text.delta'
          #   build_text_delta_chunk(data)
          # when 'response.function_call_arguments.delta'
          #   build_function_call_delta_chunk(data)
          # when 'response.output_item.added', 'response.output_item.done'
          #   build_output_item_chunk(data)
          # when 'response.content_part.added', 'response.content_part.done'
          #   build_content_part_chunk(data)
          when 'response.done'
            build_response_done_chunk(data)
          else
            # Fallback to old format for backward compatibility
            build_legacy_chunk(data)
          end
        end

        private

        def build_response_created_chunk(data)
          response_data = data['response']
          
          Chunk.new(
            role: :assistant,
            model_id: response_data['model'],
            content: nil, # response.created doesn't contain content
            tool_calls: {},
            input_tokens: response_data.dig('usage', 'input_tokens'),
            output_tokens: response_data.dig('usage', 'output_tokens')
          )
        end

        def build_text_delta_chunk(data)
          Chunk.new(
            role: :assistant,
            model_id: data['model'] || extract_model_from_response_id(data['response_id']),
            content: data['delta'],
            tool_calls: {},
            input_tokens: nil, # Token info usually comes in final events
            output_tokens: nil
          )
        end

        def build_function_call_delta_chunk(data)
          # Handle function call argument streaming
          call_id = data['call_id']
          tool_call_data = call_id ? {
            call_id => RubyLLM::ToolCall.new(
              id: call_id,
              name: nil, # Name comes from earlier events
              arguments: data['delta'] || ''
            )
          } : {}

          Chunk.new(
            role: :assistant,
            model_id: data['model'] || extract_model_from_response_id(data['response_id']),
            content: nil,
            tool_calls: tool_call_data,
            input_tokens: nil,
            output_tokens: nil
          )
        end

        def build_output_item_chunk(data)
          item = data['item']
          return build_empty_chunk unless item

          case item['type']
          when 'message'
            build_message_output_chunk(item, data)
          when 'function_call'
            build_function_call_output_chunk(item, data)
          else
            build_empty_chunk
          end
        end

        def build_content_part_chunk(data)
          part = data['part']
          return build_empty_chunk unless part

          case part['type']
          when 'text', 'output_text'
            Chunk.new(
              role: :assistant,
              model_id: data['model'] || extract_model_from_response_id(data['response_id']),
              content: part['text'],
              tool_calls: {},
              input_tokens: nil,
              output_tokens: nil
            )
          else
            build_empty_chunk
          end
        end

        def build_message_output_chunk(item, data)
          content = extract_text_from_content_array(item['content'])
          
          Chunk.new(
            role: :assistant,
            model_id: data['model'] || extract_model_from_response_id(data['response_id']),
            content: content,
            tool_calls: {},
            input_tokens: nil,
            output_tokens: nil
          )
        end

        def build_function_call_output_chunk(item, data)
          call_id = item['call_id']
          tool_call_data = call_id ? {
            call_id => RubyLLM::ToolCall.new(
              id: call_id,
              name: item['name'],
              arguments: parse_function_arguments(item['arguments'])
            )
          } : {}

          Chunk.new(
            role: :assistant,
            model_id: data['model'] || extract_model_from_response_id(data['response_id']),
            content: nil,
            tool_calls: tool_call_data,
            input_tokens: nil,
            output_tokens: nil
          )
        end

        def build_response_done_chunk(data)
          response_data = data['response']
          
          Chunk.new(
            role: :assistant,
            model_id: response_data['model'],
            content: nil,
            tool_calls: {},
            input_tokens: response_data.dig('usage', 'input_tokens'),
            output_tokens: response_data.dig('usage', 'output_tokens')
          )
        end

        def build_legacy_chunk(data)
          Chunk.new(
            role: :assistant,
            model_id: data['model'],
            content: data.dig('choices', 0, 'delta', 'content'),
            tool_calls: parse_tool_calls(data.dig('choices', 0, 'delta', 'tool_calls'), parse_arguments: false),
            input_tokens: data.dig('usage', 'prompt_tokens'),
            output_tokens: data.dig('usage', 'completion_tokens')
          )
        end

        def build_empty_chunk
          Chunk.new(
            role: :assistant,
            model_id: nil,
            content: nil,
            tool_calls: {},
            input_tokens: nil,
            output_tokens: nil
          )
        end

        def extract_text_from_content_array(content_array)
          return nil unless content_array.is_a?(Array)
          
          text_parts = content_array.select { |part| part['type'] == 'text' || part['type'] == 'output_text' }
          text_content = text_parts.map { |part| part['text'] }.compact.join
          text_content.empty? ? nil : text_content
        end

        def parse_function_arguments(arguments_string)
          return {} if arguments_string.nil? || arguments_string.empty?
          
          JSON.parse(arguments_string)
        rescue JSON::ParserError
          arguments_string
        end

        def extract_model_from_response_id(response_id)
          # Placeholder - in practice, you might need to track this differently
          # or extract it from context
          nil
        end
      end
    end
  end
end
