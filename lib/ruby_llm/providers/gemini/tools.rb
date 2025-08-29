# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini
      # Tools methods for the Gemini API implementation
      module Tools
        def format_tools(tools)
          return [] if tools.empty?

          [{
            functionDeclarations: tools.values.map { |tool| function_declaration_for(tool) }
          }]
        end

        def extract_tool_calls(data)
          return nil unless data

          candidate = data.is_a?(Hash) ? data.dig('candidates', 0) : nil
          return nil unless candidate

          parts = candidate.dig('content', 'parts')
          return nil unless parts.is_a?(Array)

          function_call_part = parts.find { |p| p['functionCall'] }
          return nil unless function_call_part

          function_data = function_call_part['functionCall']
          return nil unless function_data

          id = SecureRandom.uuid

          {
            id => ToolCall.new(
              id: id,
              name: function_data['name'],
              arguments: function_data['args']
            )
          }
        end

        private

        def function_declaration_for(tool)
          {
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters.any? ? format_parameters(tool.parameters) : nil
          }.compact
        end

        def format_parameters(parameters)
          {
            type: 'OBJECT',
            properties: parameters.transform_values { |param| format_parameter(param) },
            required: parameters.select { |_, p| p.required }.keys.map(&:to_s)
          }
        end

        def format_parameter(param)
          {
            type: param_type_for_gemini(param.type),
            description: param.description,
            items: param.items && {
              type: 'OBJECT',
              properties: format_nested_parameters(param.items)
            },
            properties: param.properties && format_nested_parameters(param.properties)
          }.compact
        end

        def format_nested_parameters(parameters)
          parameters.transform_values do |param|
            {
              type: param_type_for_gemini(param.type),
              description: param.description
            }.compact
          end
        end

        # Convert RubyLLM param types to Gemini API types
        def param_type_for_gemini(type)
          case type.to_s.downcase
          when 'integer', 'number', 'float' then 'NUMBER'
          when 'boolean' then 'BOOLEAN'
          when 'array' then 'ARRAY'
          when 'object' then 'OBJECT'
          else 'STRING'
          end
        end
      end
    end
  end
end
