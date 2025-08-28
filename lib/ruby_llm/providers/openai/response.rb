# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Response methods of the OpenAI API integration
      module Response
        def responses_url
          'responses'
        end

        module_function

        def render_response_payload(messages, tools:, temperature:, model:, cache_prompts:, stream: false, schema: nil) # rubocop:disable Metrics/ParameterLists,Lint/UnusedMethodArgument
          payload = {
            model: model.id,
            input: format_input(messages),
            stream: stream
          }

          # Only include temperature if it's not nil (some models don't accept it)
          payload[:temperature] = temperature unless temperature.nil?

          payload[:tools] = tools.map { |_, tool| response_tool_for(tool) } if tools.any?

          if schema
            # Use strict mode from schema if specified, default to true
            strict = schema[:strict] != false

            payload[:text] = {
              format: {
                type: 'json_schema',
                name: 'response',
                schema: schema,
                strict: strict
              }
            }
          end

          payload
        end

        def format_input(messages) # rubocop:disable Metrics/PerceivedComplexity
          all_tool_calls = messages.flat_map do |m|
            m.tool_calls&.values || []
          end
          messages.flat_map do |msg|
            if msg.tool_call?
              msg.tool_calls.map do |_, tc|
                {
                  type: 'function_call',
                  call_id: tc.id,
                  name: tc.name,
                  arguments: JSON.generate(tc.arguments),
                  status: 'completed'
                }
              end
            elsif msg.role == :tool
              {
                type: 'function_call_output',
                call_id: all_tool_calls.detect { |tc| tc.id == msg.tool_call_id }&.id,
                output: msg.content,
                status: 'completed'
              }
            else
              {
                type: 'message',
                role: format_role(msg.role),
                content: ResponseMedia.format_content(msg.content),
                status: 'completed'
              }.compact
            end
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

        def parse_respond_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          outputs = data['output']
          return unless outputs.any?

          Message.new(
            role: :assistant,
            content: all_output_content(outputs),
            tool_calls: parse_response_tool_calls(outputs),
            input_tokens: data['usage']['input_tokens'],
            output_tokens: data['usage']['output_tokens'],
            cached_tokens: data.dig('usage', 'input_tokens_details', 'cached_tokens'),
            model_id: data['model'],
            raw: response
          )
        end

        def all_output_content(outputs)
          text_content = extract_text_content(outputs)
          image_outputs = outputs.select { |o| o['type'] == 'image_generation_call' }

          return text_content unless image_outputs.any?

          build_content_with_images(text_content, image_outputs)
        end

        private

        def extract_text_content(outputs)
          outputs.select { |o| o['type'] == 'message' }.flat_map do |o|
            o['content'].filter_map do |c|
              c['type'] == 'output_text' && c['text']
            end
          end.join("\n")
        end

        def build_content_with_images(text_content, image_outputs)
          content = RubyLLM::Content.new(text_content)
          image_outputs.each do |output|
            attach_image_to_content(content, output)
          end
          content
        end

        def attach_image_to_content(content, output)
          image_data = output['result']
          output_format = output['output_format'] || 'png'
          mime_type = "image/#{output_format}"

          content.attach(
            RubyLLM::ImageAttachment.new(
              data: image_data,
              mime_type: mime_type,
              model_id: nil
            )
          )
        end

        def all_output_text(outputs)
          outputs.select { |o| o['type'] == 'message' }.flat_map do |o|
            o['content'].filter_map do |c|
              c['type'] == 'output_text' && c['text']
            end
          end.join("\n")
        end
      end
    end
  end
end
