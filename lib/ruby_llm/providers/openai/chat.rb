# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Chat methods of the OpenAI API integration
      module Chat
        def completion_url
          '/responses'
        end

        module_function

        def render_payload(messages, tools:, temperature:, model:, stream: false, parallel_tool_calls: true)
          {
            model: model,
            input: format_messages(messages),
            temperature: temperature,
            parallel_tool_calls: parallel_tool_calls,
            stream: stream,
            tools: build_tools_array(tools),
            tool_choice: 'auto'
          }
        end

        def parse_completion_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          # In the new API, message data is in output[0] instead of choices[0].message
          message_data = data.dig('output', 0)
          return unless message_data

          # Extract content from the new nested structure
          content = extract_content_from_output(message_data)

          Message.new(
            role: :assistant,
            content: content,
            tool_calls: parse_tool_calls(message_data['tool_calls']),
            input_tokens: data.dig('usage', 'input_tokens'),
            output_tokens: data.dig('usage', 'output_tokens'),
            model_id: data['model']
          )
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: Media.format_content(msg.content),
              tool_calls: format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact
          end
        end

        def format_role(role)
          case role
          when :system
            'developer'
          else
            role.to_s
          end
        end

        private

        def extract_content_from_output(message_data)
          # In the new API, content is an array of content blocks
          content_blocks = message_data['content']
          return nil unless content_blocks&.any?

          # Find the first text content block
          text_block = content_blocks.find { |block| block['type'] == 'output_text' }
          text_block&.dig('text')
        end

        def build_tools_array(user_tools)
          # Start with built-in tools
          built_in_tools = [{ type: 'web_search_preview' }]
          
          # Add user-provided tools if any
          if user_tools.any?
            user_tool_definitions = user_tools.map { |_, tool| tool_for(tool) }
            built_in_tools + user_tool_definitions
          else
            built_in_tools
          end
        end
      end
    end
  end
end
