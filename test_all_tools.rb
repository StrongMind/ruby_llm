#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'init_server_tools'

puts "\n🧪 Testing Client Tools with Claude 3.7 Sonnet"
puts "=" * 50
puts "Note: Claude 3.7 Sonnet doesn't support web search server tools"
puts

begin
  # Remove the web search tool since Claude 3.7 doesn't support it
  $chat.tools.delete(:web_search)
  
  # Test 1: Client tool (weather)
  puts "\n🌤️  Test 1: Client Tool (Weather) - Berlin"
  puts "Question: What's the weather in Berlin? (52.52, 13.40)"
  puts "-" * 30
  
  response1 = $chat.ask("What's the weather in Berlin? The latitude is 52.52 and longitude is 13.40.")
  puts "Response: #{response1.content}"
  puts "Tokens: #{response1.input_tokens} in, #{response1.output_tokens} out"
  puts "Model: #{response1.model_id}"

  # Test 2: Client tool with different location
  puts "\n🌤️  Test 2: Client Tool (Weather) - Tokyo"
  puts "Question: What's the weather in Tokyo? (35.68, 139.65)"
  puts "-" * 30
  
  response2 = $chat.ask("What's the weather in Tokyo? The latitude is 35.68 and longitude is 139.65.")
  puts "Response: #{response2.content}"
  puts "Tokens: #{response2.input_tokens} in, #{response2.output_tokens} out"
  puts "Model: #{response2.model_id}"

  # Test 3: Multiple locations
  puts "\n🌤️  Test 3: Client Tool (Weather) - Multiple Locations"
  puts "Question: Compare weather in Paris and New York"
  puts "-" * 30
  
  response3 = $chat.ask("Compare the weather in Paris (latitude 48.8566, longitude 2.3522) and New York (latitude 40.7128, longitude -74.0060).")
  puts "Response: #{response3.content[0..500]}..." # Truncate for readability
  puts "Tokens: #{response3.input_tokens} in, #{response3.output_tokens} out"
  puts "Model: #{response3.model_id}"

  # Summary
  puts "\n✅ All tests completed successfully!"
  puts "📊 Summary:"
  puts "  - Client tools: #{$chat.tools.values.select(&:client_tool?).map(&:name).join(', ')}"
  puts "  - Total API calls: 3"
  puts "  - Total tokens used: #{[response1, response2, response3].sum { |r| (r.input_tokens || 0) + (r.output_tokens || 0) }}"

rescue => e
  puts "❌ Error during testing: #{e.message}"
  puts e.backtrace[0..3]
end 