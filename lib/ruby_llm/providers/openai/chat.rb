# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Chat methods of the OpenAI API integration
      module Chat
        def completion_url
          'chat/completions'
        end

        module_function

        def render_payload(messages, tools:, temperature:, model:, stream: false)
          payload = {
            model: model,
            messages: format_messages(messages),
            stream: stream
          }
          
          # Only add temperature if it's not nil
          payload[:temperature] = temperature unless temperature.nil?
          
          # Separate client and server tools
          client_tools = tools.values.select(&:client_tool?)
          server_tools = tools.values.select(&:server_tool?)
          
          # Add client tools to the tools array
          if client_tools.any?
            payload[:tools] = client_tools.map { |tool| tool_for(tool) }
            payload[:tool_choice] = 'auto'
          end
          
          # Handle server tools based on their type
          server_tools.each do |tool|
            case tool.type
            when 'web_search', 'web_search_20250305'
              # For OpenAI web search, add web_search_options
              payload[:web_search_options] = {}
            end
          end
          
          payload[:stream_options] = { include_usage: true } if stream
          
          payload
        end

        def parse_completion_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          message_data = data.dig('choices', 0, 'message')
          return unless message_data

          # Extract content, which may include web search results
          content = extract_content_with_search_results(message_data)

          Message.new(
            role: :assistant,
            content: content,
            tool_calls: parse_tool_calls(message_data['tool_calls']),
            input_tokens: data['usage']['prompt_tokens'],
            output_tokens: data['usage']['completion_tokens'],
            model_id: data['model']
          )
        end

        def extract_content_with_search_results(message_data)
          content = message_data['content']
          
          # Check if there are web search results in the message
          # OpenAI may include search metadata in the response
          if message_data['search_results']
            # Format search results as part of the content
            # This is a placeholder - actual format depends on OpenAI's response structure
            content
          else
            content
          end
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
      end
    end
  end
end
