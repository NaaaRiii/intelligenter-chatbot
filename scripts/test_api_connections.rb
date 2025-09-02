#!/usr/bin/env ruby
# APIキーが正しく設定されているか実際にAPIを呼び出してテストするスクリプト

require_relative '../config/environment'

puts "=" * 60
puts "API Connection Test"
puts "=" * 60

# OpenAI API テスト
puts "\n[Testing OpenAI API]"
begin
  openai_service = OpenaiChatService.new
  
  # シンプルなテストメッセージ
  test_prompt = "こんにちは。これはテストメッセージです。簡単に返信してください。"
  
  puts "Sending test message to OpenAI..."
  response = openai_service.generate_response(test_prompt)
  
  if response && response.length > 0
    puts "✅ OpenAI API connection successful!"
    puts "Response preview: #{response[0..100]}..."
  else
    puts "❌ OpenAI API returned empty response"
  end
rescue => e
  puts "❌ OpenAI API Error: #{e.message}"
  puts "Error class: #{e.class}"
end

# Claude API テスト
puts "\n[Testing Claude API]"
begin
  claude_service = ClaudeApiService.new
  
  # シンプルなテスト会話履歴
  test_history = [
    { role: 'user', content: 'こんにちは' },
    { role: 'assistant', content: 'こんにちは！どのようなご用件でしょうか？' }
  ]
  test_message = "システムのテストをしています"
  
  puts "Sending test message to Claude..."
  response = claude_service.generate_response(test_history, test_message)
  
  if response && response.length > 0
    puts "✅ Claude API connection successful!"
    puts "Response preview: #{response[0..100]}..."
  else
    puts "❌ Claude API returned empty response"
  end
rescue => e
  puts "❌ Claude API Error: #{e.message}"
  puts "Error class: #{e.class}"
  
  if e.message.include?('401') || e.message.include?('Unauthorized')
    puts "\n⚠️  認証エラーです。APIキーが正しく設定されているか確認してください。"
  end
end

# NaturalConversationService テスト
puts "\n[Testing NaturalConversationService]"
begin
  natural_service = NaturalConversationService.new
  
  # 複数質問のテスト
  test_message = "楽天との連携はできますか？また、セキュリティ対策はどうなっていますか？"
  test_history = []
  
  puts "Testing natural conversation with multiple questions..."
  response = natural_service.generate_natural_response(test_message, test_history)
  
  if response && response.length > 0
    puts "✅ NaturalConversationService working!"
    puts "Response preview: #{response[0..150]}..."
  else
    puts "❌ NaturalConversationService returned empty response"
  end
rescue => e
  puts "❌ NaturalConversationService Error: #{e.message}"
end

puts "\n" + "=" * 60
puts "Configuration Summary:"
puts "=" * 60

# 設定値の確認（実際の値は表示しない）
openai_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
anthropic_key = Rails.application.credentials.dig(:anthropic, :api_key) || ENV['ANTHROPIC_API_KEY']

puts "OpenAI API Key source: #{Rails.application.credentials.dig(:openai, :api_key) ? 'Rails credentials' : (ENV['OPENAI_API_KEY'] ? 'Environment variable' : 'Not configured')}"
puts "Anthropic API Key source: #{Rails.application.credentials.dig(:anthropic, :api_key) ? 'Rails credentials' : (ENV['ANTHROPIC_API_KEY'] ? 'Environment variable' : 'Not configured')}"

if openai_key
  puts "OpenAI Key length: #{openai_key.length} characters"
end

if anthropic_key
  puts "Anthropic Key length: #{anthropic_key.length} characters"
end

puts "\nTo check your Rails credentials configuration:"
puts "  rails console"
puts "  > Rails.application.credentials.openai"
puts "  > Rails.application.credentials.anthropic"