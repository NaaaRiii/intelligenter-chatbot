#!/bin/bash
# チャットボットのAI応答ログを監視するスクリプト

echo "=========================================="
echo "Chat Bot AI Response Monitor"
echo "=========================================="
echo ""
echo "Monitoring for AI responses in development.log..."
echo "Open http://localhost:4002/chat in your browser to test"
echo ""
echo "Press Ctrl+C to stop monitoring"
echo ""
echo "------------------------------------------"

# ログファイルをリアルタイムで監視し、AI関連のログをフィルタリング
tail -f log/development.log | grep -E "\[PROCESS_AI|NaturalConversation|OpenAI|Claude|ChatBot|AI Response" --color=always