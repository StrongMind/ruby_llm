#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dotenv/load'
require_relative 'lib/ruby_llm'

# Check if environment variables are set
puts "🔍 Checking environment variables..."
aws_access_key = ENV['AWS_ACCESS_KEY_ID']
aws_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
aws_region = ENV['AWS_REGION'] || 'us-west-2'

if aws_access_key.nil? || aws_access_key.empty?
  puts "❌ AWS_ACCESS_KEY_ID is not set"
  puts "Please create a .env file with:"
  puts "AWS_ACCESS_KEY_ID=your_access_key"
  puts "AWS_SECRET_ACCESS_KEY=your_secret_key"
  puts "AWS_REGION=us-west-2"
  exit 1
end

if aws_secret_key.nil? || aws_secret_key.empty?
  puts "❌ AWS_SECRET_ACCESS_KEY is not set"
  puts "Please create a .env file with:"
  puts "AWS_ACCESS_KEY_ID=your_access_key"
  puts "AWS_SECRET_ACCESS_KEY=your_secret_key"
  puts "AWS_REGION=us-west-2"
  exit 1
end

puts "✅ Environment variables loaded:"
puts "  AWS_ACCESS_KEY_ID: #{aws_access_key[0..8]}..."
puts "  AWS_SECRET_ACCESS_KEY: #{aws_secret_key[0..8]}..."
puts "  AWS_REGION: #{aws_region}"
puts

# Configure RubyLLM with your credentials
puts "🔧 Configuring RubyLLM..."
RubyLLM.configure do |config|
  config.bedrock_api_key = aws_access_key
  config.bedrock_secret_key = aws_secret_key
  config.bedrock_region = aws_region
  config.bedrock_session_token = ENV['AWS_SESSION_TOKEN'] # Optional
end

# Define a simple client tool for testing
class WeatherTool < RubyLLM::Tool
  description 'Gets current weather for a location'
  param :latitude, desc: 'Latitude (e.g., 52.5200)'
  param :longitude, desc: 'Longitude (e.g., 13.4050)'

  def execute(latitude:, longitude:)
    "Current weather at #{latitude}, #{longitude}: 15°C, partly cloudy, wind 10 km/h"
  end
end

puts "🛠️  Creating tools..."
# Create the tools
$weather_tool = WeatherTool.new
$web_search_tool = RubyLLM::WebSearchTool.new

puts "💬 Creating chat instance..."
# Create and configure the chat
begin
  $chat = RubyLLM.chat(
    model: 'anthropic.claude-3-5-sonnet-20241022-v2:0',
    provider: :bedrock
  )

  $chat.with_tool($weather_tool)
  $chat.with_tool($web_search_tool)

  puts "🚀 Server Tools Initialized!"
  puts "=" * 40
  puts "Available global variables:"
  puts "  $chat - Chat instance with both tools"
  puts "  $weather_tool - Client tool (executed locally)"
  puts "  $web_search_tool - Server tool (executed by Anthropic)"
  puts
  puts "Example usage:"
  puts "  $chat.ask('What\\'s the weather in Berlin? (52.52, 13.40)')"
  puts "  $chat.ask('What\\'s the latest news about Ruby?')"
  puts "  $chat.ask('Weather in Tokyo (35.68, 139.65) and news about Japan?')"
  puts
  puts "Ready to test! 🎉"

rescue RubyLLM::ConfigurationError => e
  puts "❌ Configuration Error: #{e.message}"
  puts
  puts "This usually means:"
  puts "1. Your AWS credentials are not valid"
  puts "2. You don't have access to Anthropic models through Bedrock"
  puts "3. The region is incorrect"
  puts
  puts "Please check:"
  puts "- Your AWS credentials are correct"
  puts "- You have Bedrock access in region: #{aws_region}"
  puts "- Anthropic models are enabled in your Bedrock console"
  exit 1
rescue => e
  puts "❌ Unexpected Error: #{e.message}"
  puts e.backtrace[0..3]
  exit 1
end 