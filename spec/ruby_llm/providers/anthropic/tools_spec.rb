# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Tools do
  let(:tools) { described_class }

  describe '.format_tool_call' do
    let(:msg) do
      instance_double(RubyLLM::Message,
                      content: 'Some content',
                      tool_calls: {
                        'tool_123' => instance_double(RubyLLM::ToolCall,
                                                      id: 'tool_123',
                                                      name: 'test_tool',
                                                      arguments: { 'arg1' => 'value1' })
                      })
    end

    it 'formats a message with content and tool call' do
      result = tools.format_tool_call(msg)

      expect(result).to eq({
                             role: 'assistant',
                             content: [
                               { type: 'text', text: 'Some content' },
                               {
                                 type: 'tool_use',
                                 id: 'tool_123',
                                 name: 'test_tool',
                                 input: { 'arg1' => 'value1' }
                               }
                             ]
                           })
    end

    context 'when message has no content' do
      let(:msg) do
        instance_double(RubyLLM::Message,
                        content: nil,
                        tool_calls: {
                          'tool_123' => instance_double(RubyLLM::ToolCall,
                                                        id: 'tool_123',
                                                        name: 'test_tool',
                                                        arguments: { 'arg1' => 'value1' })
                        })
      end

      it 'formats a message with only tool call' do
        result = tools.format_tool_call(msg)

        expect(result).to eq({
                               role: 'assistant',
                               content: [
                                 {
                                   type: 'tool_use',
                                   id: 'tool_123',
                                   name: 'test_tool',
                                   input: { 'arg1' => 'value1' }
                                 }
                               ]
                             })
      end
    end

    context 'when message has empty content' do
      let(:msg) do
        instance_double(RubyLLM::Message,
                        content: '',
                        tool_calls: {
                          'tool_123' => instance_double(RubyLLM::ToolCall,
                                                        id: 'tool_123',
                                                        name: 'test_tool',
                                                        arguments: { 'arg1' => 'value1' })
                        })
      end

      it 'formats a message with only tool call' do
        result = tools.format_tool_call(msg)

        expect(result).to eq({
                               role: 'assistant',
                               content: [
                                 {
                                   type: 'tool_use',
                                   id: 'tool_123',
                                   name: 'test_tool',
                                   input: { 'arg1' => 'value1' }
                                 }
                               ]
                             })
      end
    end

    it 'formats messages with multiple tool calls correctly' do
      tool_calls = {
        'tool_1' => RubyLLM::ToolCall.new(id: 'tool_1', name: 'dice_roll', arguments: {}),
        'tool_2' => RubyLLM::ToolCall.new(id: 'tool_2', name: 'dice_roll', arguments: {}),
        'tool_3' => RubyLLM::ToolCall.new(id: 'tool_3', name: 'dice_roll', arguments: {})
      }

      msg = RubyLLM::Message.new(
        role: :assistant,
        content: 'Rolling dice 3 times',
        tool_calls: tool_calls
      )

      formatted = described_class.format_tool_call(msg)

      expect(formatted[:role]).to eq('assistant')
      expect(formatted[:content].size).to eq(4) # 1 text + 3 tool_use blocks

      # Check text content
      expect(formatted[:content][0]).to eq({ type: 'text', text: 'Rolling dice 3 times' })
      # Check all 3 tool use blocks are present
      tool_use_blocks = formatted[:content][1..3]
      expect(tool_use_blocks.map { |b| b[:type] }).to all(eq('tool_use'))
      expect(tool_use_blocks.map { |b| b[:id] }).to contain_exactly('tool_1', 'tool_2', 'tool_3')
      expect(tool_use_blocks.map { |b| b[:name] }).to all(eq('dice_roll'))
    end

    it 'does not include empty text content with multiple tool calls' do
      tool_calls = {
        'tool_1' => RubyLLM::ToolCall.new(id: 'tool_1', name: 'dice_roll', arguments: {})
      }

      msg = RubyLLM::Message.new(
        role: :assistant,
        content: '', # Empty content
        tool_calls: tool_calls
      )

      formatted = described_class.format_tool_call(msg)

      expect(formatted[:role]).to eq('assistant')
      expect(formatted[:content].size).to eq(1) # Only tool_use block, no text
      expect(formatted[:content][0][:type]).to eq('tool_use')
    end
  end

  describe '.format_tool_result' do
    let(:msg) do
      instance_double(RubyLLM::Message,
                      tool_call_id: 'tool_123',
                      content: 'Tool result')
    end

    it 'formats a tool result message' do
      result = tools.format_tool_result(msg)

      expect(result).to eq({
                             role: 'user',
                             content: [
                               {
                                 type: 'tool_result',
                                 tool_use_id: 'tool_123',
                                 content: [
                                   {
                                     type: 'text',
                                     text: 'Tool result'
                                   }
                                 ]
                               }
                             ]
                           })
    end
  end

  describe '.parse_tool_calls' do
    it 'parses multiple tool calls from content blocks' do
      content_blocks = [
        { 'type' => 'text', 'text' => 'Rolling dice' },
        { 'type' => 'tool_use', 'id' => 'tool_1', 'name' => 'dice_roll', 'input' => {} },
        { 'type' => 'tool_use', 'id' => 'tool_2', 'name' => 'dice_roll', 'input' => {} },
        { 'type' => 'tool_use', 'id' => 'tool_3', 'name' => 'dice_roll', 'input' => {} }
      ]

      tool_calls = described_class.parse_tool_calls(content_blocks)

      expect(tool_calls).to be_a(Hash)
      expect(tool_calls.size).to eq(3)
      expect(tool_calls.keys).to contain_exactly('tool_1', 'tool_2', 'tool_3')
      expect(tool_calls.values.map(&:name)).to all(eq('dice_roll'))
    end

    it 'handles single tool call for backward compatibility' do
      single_block = { 'type' => 'tool_use', 'id' => 'tool_1', 'name' => 'dice_roll', 'input' => {} }

      tool_calls = described_class.parse_tool_calls(single_block)

      expect(tool_calls).to be_a(Hash)
      expect(tool_calls.size).to eq(1)
      expect(tool_calls['tool_1'].name).to eq('dice_roll')
    end

    it 'returns nil for empty or nil input' do
      expect(described_class.parse_tool_calls(nil)).to be_nil
      expect(described_class.parse_tool_calls([])).to be_nil
    end

    it 'ignores server_tool_use blocks (like web search)' do
      content_blocks = [
        { 'type' => 'text', 'text' => 'Searching...' },
        { 'type' => 'server_tool_use', 'id' => 'search_1', 'name' => 'web_search', 'input' => { 'query' => 'test' } },
        { 'type' => 'tool_use', 'id' => 'tool_1', 'name' => 'custom_tool', 'input' => {} }
      ]

      tool_calls = described_class.parse_tool_calls(content_blocks)

      # Should only include the regular tool_use, not server_tool_use
      expect(tool_calls).to be_a(Hash)
      expect(tool_calls.size).to eq(1)
      expect(tool_calls['tool_1'].name).to eq('custom_tool')
    end
  end

  describe '.find_tool_uses' do
    it 'finds only tool_use blocks, not server_tool_use blocks' do
      content_blocks = [
        { 'type' => 'text', 'text' => 'Some text' },
        { 'type' => 'server_tool_use', 'id' => 'search_1', 'name' => 'web_search', 'input' => {} },
        { 'type' => 'tool_use', 'id' => 'tool_1', 'name' => 'custom_tool', 'input' => {} },
        { 'type' => 'web_search_tool_result', 'tool_use_id' => 'search_1', 'content' => [] }
      ]

      tool_uses = described_class.find_tool_uses(content_blocks)

      expect(tool_uses.size).to eq(1)
      expect(tool_uses[0]['type']).to eq('tool_use')
      expect(tool_uses[0]['name']).to eq('custom_tool')
    end
  end

  describe '.function_for' do
    it 'formats a regular tool definition' do
      tool = instance_double(RubyLLM::Tool,
                             name: 'test_tool',
                             description: 'A test tool',
                             parameters: {
                               query: instance_double(RubyLLM::Parameter,
                                                      type: 'string',
                                                      description: 'Search query',
                                                      required: true,
                                                      items: nil,
                                                      properties: nil)
                             })

      result = described_class.function_for(tool)

      expect(result).to eq({
                             name: 'test_tool',
                             description: 'A test tool',
                             input_schema: {
                               type: 'object',
                               properties: {
                                 query: {
                                   type: 'string',
                                   description: 'Search query'
                                 }
                               },
                               required: [:query]
                             }
                           })
    end

    it 'formats WebSearch tool definition' do
      web_search = RubyLLM::Providers::Anthropic::WebSearch.new(max_uses: 5)

      result = described_class.function_for(web_search)

      expect(result).to eq({
                             type: 'web_search_20250305',
                             name: 'web_search',
                             max_uses: 5
                           })
    end

    it 'formats WebSearch tool definition without max_uses' do
      web_search = RubyLLM::Providers::Anthropic::WebSearch.new

      result = described_class.function_for(web_search)

      expect(result).to eq({
                             type: 'web_search_20250305',
                             name: 'web_search'
                           })
    end
  end
end
