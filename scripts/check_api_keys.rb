#!/usr/bin/env ruby
# API キーの設定状況を確認するスクリプト

require 'dotenv/load'

puts "=" * 60
puts "API Key Configuration Check"
puts "=" * 60

# 環境変数から取得
openai_key = ENV['OPENAI_API_KEY']
anthropic_key = ENV['ANTHROPIC_API_KEY']

puts "\n[Environment Variables]"
puts "OPENAI_API_KEY: #{openai_key ? '✅ Set (length: ' + openai_key.length.to_s + ')' : '❌ Not set'}"
puts "ANTHROPIC_API_KEY: #{anthropic_key ? '✅ Set (length: ' + anthropic_key.length.to_s + ')' : '❌ Not set'}"

# 実際のキーの先頭文字を表示（セキュリティのため一部のみ）
if openai_key
  masked_key = openai_key[0..7] + ('*' * (openai_key.length - 8))
  puts "  OpenAI Key preview: #{masked_key}"
end

if anthropic_key
  masked_key = anthropic_key[0..7] + ('*' * (anthropic_key.length - 8))
  puts "  Anthropic Key preview: #{masked_key}"
end

puts "\n[Validation]"
# OpenAI APIキーの基本的な検証
if openai_key
  if openai_key.start_with?('sk-')
    puts "✅ OpenAI key format looks valid (starts with 'sk-')"
  else
    puts "⚠️  OpenAI key format may be invalid (should start with 'sk-')"
  end
else
  puts "❌ OpenAI API key is not configured"
end

# Anthropic APIキーの基本的な検証
if anthropic_key
  if anthropic_key.start_with?('sk-ant-')
    puts "✅ Anthropic key format looks valid (starts with 'sk-ant-')"
  elsif anthropic_key == 'your_anthropic_api_key_here'
    puts "❌ Anthropic key is still the placeholder value"
  else
    puts "⚠️  Anthropic key format may be invalid (should start with 'sk-ant-')"
  end
else
  puts "❌ Anthropic API key is not configured"
end

puts "\n[Rails Credentials Check]"
puts "To check Rails credentials, run:"
puts "  rails console"
puts "  > Rails.application.credentials.dig(:openai, :api_key)"
puts "  > Rails.application.credentials.dig(:anthropic, :api_key)"

puts "\n[Setting API Keys]"
if !openai_key || openai_key == 'your_openai_api_key_here'
  puts "\nTo set OpenAI API key:"
  puts "  1. Get your API key from: https://platform.openai.com/api-keys"
  puts "  2. Add to .env file:"
  puts "     OPENAI_API_KEY=sk-..."
end

if !anthropic_key || anthropic_key == 'your_anthropic_api_key_here'
  puts "\nTo set Anthropic API key:"
  puts "  1. Get your API key from: https://console.anthropic.com/settings/keys"
  puts "  2. Add to .env file:"
  puts "     ANTHROPIC_API_KEY=sk-ant-..."
end

puts "\n" + "=" * 60