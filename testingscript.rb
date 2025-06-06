#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'ruby_llm'
require 'pp'

require 'dotenv'
Dotenv.load

# Define a tool
class Calculator < RubyLLM::Tool
  description 'Performs basic arithmetic operations on two numbers'
  
  param :operation, 
        type: 'string', 
        desc: 'The operation to perform: add, subtract, multiply, or divide'
  
  param :a, 
        type: 'number', 
        desc: 'The first number'
  
  param :b, 
        type: 'number', 
        desc: 'The second number'

  def execute(operation:, a:, b:)
    case operation.downcase
    when 'add'
      result = a + b
      "#{a} + #{b} = #{result}"
    when 'subtract'
      result = a - b
      "#{a} - #{b} = #{result}"
    when 'multiply'
      result = a * b
      "#{a} × #{b} = #{result}"
    when 'divide'
      return "Error: Cannot divide by zero" if b == 0
      result = a / b
      "#{a} ÷ #{b} = #{result}"
    else
      "Error: Unknown operation '#{operation}'. Use add, subtract, multiply, or divide."
    end
  rescue StandardError => e
    "Error performing calculation: #{e.message}"
  end
end

class AccuracyScorer < RubyLLM::Tool
  description 'Records evaluation scores for statement accuracy based on web search verification. Give a score of 0 if the statement is inaccurate. Give a score of 1 if the statement is accurate.'
  
  param :statement, 
        type: 'string', 
        desc: 'The statement being evaluated for accuracy'
  
  param :score, 
        type: 'number', 
        desc: 'The accuracy score: 0 for inaccurate, 1 for accurate'
  
  param :justification, 
        type: 'string', 
        desc: 'The justification for the score given based on web search results'
  
  param :evidence, 
        type: 'string', 
        desc: 'The evidence from web search that supports the accuracy score'

  def execute(statement:, score:, justification:, evidence:)
    # Validate score is 0 or 1
    unless [0, 1].include?(score)
      return "Error: Score must be 0 (inaccurate) or 1 (accurate). Received: #{score}"
    end
    
    accuracy_label = score == 1 ? 'accurate' : 'inaccurate'
    
    {
      result: "Accuracy evaluation completed for statement: '#{statement}'",
      score: score,
      accuracy: accuracy_label,
      justification: justification,
      evidence: evidence
    }.to_json
  rescue StandardError => e
    "Error recording accuracy score: #{e.message}"
  end
end

def fetch_tool_calls(response)
  all_tool_calls_details = []
  response.each do |message|
    unless message.tool_calls.nil?
      all_tool_calls_details << message.tool_calls
    end
  end
  puts "poop POOP all tool calls details: #{all_tool_calls_details}"
  all_tool_calls_details
end

RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_ACCESS_TOKEN', nil)
end

begin
  chat = RubyLLM.chat(model: 'gpt-4o', provider: 'openai')
  chat.with_tool(Calculator)
  chat.with_tool(AccuracyScorer)

  first_prompt = 'Use web_search to verify the current factual accuracy of this statement: "The current pope is Francis." Search for reliable, up-to-date information about who is the current pope. Then, use the accuracy scorer tool to give the statement an accuracy score based on your web search results from reliable sources. Give a score of 0 if the statement is inaccurate. Give a score of 1 if the statement is accurate. After using the accuracy scorer tool, respond with ONLY the numerical score (0 or 1) and nothing else.'
  puts "Generating response with OpenAI gpt-4o: '#{first_prompt}'"

  response = chat.ask(first_prompt)

  puts "Response: #{response.content}"

  puts "\n" + "="*50

  puts "Response tool calls: #{fetch_tool_calls(chat.messages)}"
  puts "\n" + "="*50
  
rescue RubyLLM::UnauthorizedError
  puts 'Error: Invalid OpenAI API key.'
rescue RubyLLM::BadRequestError => e
  puts "Error: Bad Request - #{e.message}"
rescue RubyLLM::RateLimitError
  puts 'Error: Rate limit exceeded.'
rescue RubyLLM::Error => e
  puts "Response generation failed: #{e.message}"
rescue StandardError => e
  puts "Unexpected error: #{e.message}"
  puts e.backtrace
end