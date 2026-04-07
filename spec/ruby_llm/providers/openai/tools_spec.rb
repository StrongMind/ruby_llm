# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Tools do # rubocop:disable RSpec/SpecFilePathFormat
  class ClassificationProbeTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Probe classification schema serialization'

    param :content, desc: 'The classification question content'
    param :possible_responses,
          type: 'array',
          desc: 'Array of response choices',
          items: { type: 'string' }
    param :column_titles,
          type: 'array',
          desc: 'Array of column titles',
          items: { type: 'string' }
    param :column_values,
          type: 'array',
          desc: 'Array of arrays containing item indices',
          items: {
            type: 'array',
            items: { type: 'integer' }
          }

    def execute(...) = nil
  end

  class StateManagerProbeTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Probe shorthand object serialization'

    param :states,
          type: 'array',
          desc: 'List of states',
          items: {
            name: {
              type: 'string',
              desc: 'The state name'
            },
            capital: {
              type: 'string',
              desc: 'The capital city'
            }
          }

    def execute(...) = nil
  end

  describe '.tool_parameters_for' do
    it 'serializes scalar and nested array items as valid JSON schema' do
      schema = described_class.tool_parameters_for(ClassificationProbeTool.new)

      expect(schema).to eq(
        {
          type: 'object',
          properties: {
            content: {
              type: 'string',
              description: 'The classification question content'
            },
            possible_responses: {
              type: 'array',
              description: 'Array of response choices',
              items: { type: 'string' }
            },
            column_titles: {
              type: 'array',
              description: 'Array of column titles',
              items: { type: 'string' }
            },
            column_values: {
              type: 'array',
              description: 'Array of arrays containing item indices',
              items: {
                type: 'array',
                items: { type: 'integer' }
              }
            }
          },
          required: %i[content possible_responses column_titles column_values]
        }
      )
    end

    it 'preserves shorthand object item definitions' do
      schema = described_class.tool_parameters_for(StateManagerProbeTool.new)

      expect(schema).to eq(
        {
          type: 'object',
          properties: {
            states: {
              type: 'array',
              description: 'List of states',
              items: {
                type: 'object',
                properties: {
                  name: {
                    type: 'string',
                    description: 'The state name'
                  },
                  capital: {
                    type: 'string',
                    description: 'The capital city'
                  }
                }
              }
            }
          },
          required: [:states]
        }
      )
    end
  end
end
