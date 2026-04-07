# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Tools do # rubocop:disable RSpec/SpecFilePathFormat
  class GeminiArrayTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Tool with array items'

    param :items,
          type: 'array',
          desc: 'List of items',
          items: {
            name: { type: 'string', desc: 'Item name' },
            quantity: { type: 'number', desc: 'Item count' }
          }

    def execute(...) = nil
  end

  class GeminiScalarArrayTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Tool with scalar array items'

    param :tags,
          type: 'array',
          desc: 'List of tags',
          items: { type: 'string' }
    param :nested_arrays,
          type: 'array',
          desc: 'Nested arrays',
          items: {
            type: 'array',
            items: { type: 'integer' }
          }

    def execute(...) = nil
  end

  class GeminiNestedObjectTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Tool with nested object properties'

    param :contact,
          type: 'object',
          desc: 'Contact info',
          properties: {
            name: { type: 'string', desc: 'Full name' },
            address: {
              type: 'object',
              desc: 'Address',
              properties: {
                city: { type: 'string', desc: 'City name' }
              }
            }
          }

    def execute(...) = nil
  end

  let(:test_obj) do
    Object.new.tap do |obj|
      obj.extend(described_class)
    end
  end

  describe '#format_parameters' do
    it 'serializes shorthand object items in arrays' do
      result = test_obj.send(:format_parameters, GeminiArrayTool.parameters)

      expect(result[:properties][:items]).to eq(
        type: 'ARRAY',
        description: 'List of items',
        items: {
          type: 'OBJECT',
          properties: {
            name: { type: 'STRING', description: 'Item name' },
            quantity: { type: 'NUMBER', description: 'Item count' }
          }
        }
      )
    end

    it 'serializes scalar array items' do
      result = test_obj.send(:format_parameters, GeminiScalarArrayTool.parameters)

      expect(result[:properties][:tags]).to eq(
        type: 'ARRAY',
        description: 'List of tags',
        items: { type: 'STRING' }
      )
    end

    it 'serializes nested array items' do
      result = test_obj.send(:format_parameters, GeminiScalarArrayTool.parameters)

      expect(result[:properties][:nested_arrays]).to eq(
        type: 'ARRAY',
        description: 'Nested arrays',
        items: {
          type: 'ARRAY',
          items: { type: 'NUMBER' }
        }
      )
    end

    it 'serializes nested object properties' do
      result = test_obj.send(:format_parameters, GeminiNestedObjectTool.parameters)

      expect(result[:properties][:contact]).to eq(
        type: 'OBJECT',
        description: 'Contact info',
        properties: {
          name: { type: 'STRING', description: 'Full name' },
          address: {
            type: 'OBJECT',
            description: 'Address',
            properties: {
              city: { type: 'STRING', description: 'City name' }
            }
          }
        }
      )
    end
  end
end
