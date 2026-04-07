# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini
      # Tools methods for the Gemini API implementation
      module Tools
        PARAM_TYPE_MAP = {
          'integer' => 'NUMBER',
          'number' => 'NUMBER',
          'float' => 'NUMBER',
          'boolean' => 'BOOLEAN',
          'array' => 'ARRAY',
          'object' => 'OBJECT',
          'string' => 'STRING'
        }.freeze

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
            properties: parameters.transform_values do |param|
              Parameter.serialize_schema(param.to_schema) { |type| param_type_for_gemini(type) }
            end,
            required: parameters.select { |_, p| p.required }.keys.map(&:to_s)
          }
        end

        # Convert RubyLLM param types to Gemini API types
        def param_type_for_gemini(type)
          PARAM_TYPE_MAP.fetch(type.to_s.downcase) do
            raise KeyError, "Unsupported Gemini parameter type: #{type.inspect}"
          end
        end
      end
    end
  end
end
