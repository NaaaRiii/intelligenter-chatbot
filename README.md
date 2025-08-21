# インテリジェントチャットボット分析システム

## 概要
顧客の問い合わせに対応し、会話データから隠れたニーズを抽出する次世代チャットボットシステム。

## 主な機能
- リアルタイムチャット対応
- AI による会話分析
- 顧客インサイトの可視化
- ビジネス戦略の提案

## 技術スタック（予定）
- Backend: Ruby on Rails 7.1
- Database: PostgreSQL 15
- Real-time: ActionCable (WebSocket)
- AI: Claude API (Anthropic)
- Frontend: TypeScript + Vite + Stimulus

## プロジェクトステータス
🔄 計画・設計段階

## 開発環境セットアップ

### 必要なソフトウェア
- Docker Desktop
- Git

### セットアップ手順

```bash
# リポジトリをクローン
git clone https://github.com/NaaaRiii/intelligenter-chatbot.git
cd intelligenter-chatbot

# Docker環境を構築・起動
make setup

# または個別に実行
docker-compose build
docker-compose up -d
```

### 開発用コマンド

```bash
# コンテナ起動
make up

# コンテナ停止
make down

# ログ確認
make logs

# Railsコンソール
make console

# テスト実行
make test

# データベースリセット
make db-reset
```

### アクセスURL
- Rails: http://localhost:3000
- Vite: http://localhost:3036
