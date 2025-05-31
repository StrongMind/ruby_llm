# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Chat methods of the OpenAI API integration
      module Chat
        def completion_url
          'responses'
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

          outputs = data['output']              # <-- correct key
          Rails.logger.debug "poop outputs in parse completion response: #{outputs.inspect}"
          return unless outputs&.any?

          assistant_text = nil
          raw_calls      = []
          Rails.logger.debug "poop assistant_text in parse completion response: #{assistant_text.inspect}"
          Rails.logger.debug "poop raw_calls in parse completion response: #{raw_calls.inspect}"

          outputs.each do |block|
            case block['type']
            when 'text'
              assistant_text ||= block['text']  # keep first text block (if any)
            when 'function_call'
              raw_calls << block
            end
          end

          Message.new(
            role: :assistant,
            content: assistant_text,
            tool_calls: parse_tool_calls(raw_calls),
            input_tokens: data.dig('usage', 'input_tokens'),
            output_tokens: data.dig('usage', 'output_tokens'),
            model_id: data['model']
          )
        end

        def format_messages(messages)
          formatted_messages = []

          messages.each do |msg|
            if msg.tool_call?
              # Add the tool call message as it came back from the API
              msg.tool_calls.each_value do |tool_call|
                formatted_messages << {
                  type: 'function_call',
                  id: tool_call.id,
                  call_id: tool_call.call_id,
                  name: tool_call.name,
                  arguments: JSON.generate(tool_call.arguments),
                  status: tool_call.status
                }
              end
            elsif msg.tool_result?
              # Add the tool output message
              formatted_messages << {
                type: 'function_call_output',
                call_id: msg.tool_call_id,
                output: msg.content.to_s
              }
            else
              # Regular message
              formatted_messages << {
                role: format_role(msg.role),
                content: Media.format_content(msg.content)
              }.compact
            end
          end

          formatted_messages
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

        def parse_tool_calls(raw_calls)
          return nil unless raw_calls&.any?

          raw_calls.to_h do |tc|
            [
              tc['call_id'] || tc['id'],
              ToolCall.new(
                id: tc['call_id'] || tc['id'],
                name: tc['name'],
                arguments: tc['arguments'].is_a?(String) ? JSON.parse(tc['arguments']) : tc['arguments']
              )
            ]
          end
        end

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
