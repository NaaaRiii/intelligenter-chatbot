.PHONY: help build up down restart logs shell db-create db-migrate db-seed db-reset test clean

# デフォルトターゲット
help:
	@echo "利用可能なコマンド:"
	@echo "  make build      - Dockerイメージをビルド"
	@echo "  make up         - コンテナを起動"
	@echo "  make down       - コンテナを停止・削除"
	@echo "  make restart    - コンテナを再起動"
	@echo "  make logs       - ログを表示"
	@echo "  make shell      - Railsコンテナにシェルで接続"
	@echo "  make console    - Railsコンソールを起動"
	@echo "  make db-create  - データベース作成"
	@echo "  make db-migrate - マイグレーション実行"
	@echo "  make db-seed    - シードデータ投入"
	@echo "  make db-reset   - データベースリセット"
	@echo "  make test       - テスト実行"
	@echo "  make clean      - ボリューム含めて全削除"

# Docker操作
build:
	docker-compose build

up:
	docker-compose up -d
	@echo "アプリケーション起動中..."
	@echo "Rails: http://localhost:3000"
	@echo "Vite: http://localhost:3036"

down:
	docker-compose down

restart:
	docker-compose restart

logs:
	docker-compose logs -f

# 個別サービスのログ
logs-app:
	docker-compose logs -f app

logs-sidekiq:
	docker-compose logs -f sidekiq

logs-vite:
	docker-compose logs -f vite

# シェルアクセス
shell:
	docker-compose exec app bash

console:
	docker-compose exec app bundle exec rails console

# データベース操作
db-create:
	docker-compose exec app bundle exec rails db:create

db-migrate:
	docker-compose exec app bundle exec rails db:migrate

db-seed:
	docker-compose exec app bundle exec rails db:seed

db-reset:
	docker-compose exec app bundle exec rails db:drop db:create db:migrate db:seed

db-shell:
	docker-compose exec postgres psql -U chatbot -d chatbot_development

# テスト
test:
	docker-compose exec app bundle exec rspec

test-frontend:
	docker-compose exec app npm test

lint:
	docker-compose exec app bundle exec rubocop
	docker-compose exec app npm run lint

# クリーンアップ
clean:
	docker-compose down -v
	docker system prune -f

# 開発環境セットアップ（初回実行用）
setup: build up
	@echo "初回セットアップ実行中..."
	sleep 10
	make db-create
	make db-migrate
	@echo "セットアップ完了！"
	@echo "http://localhost:3000 でアクセスできます"

# ステータス確認
status:
	docker-compose ps

# ヘルスチェック
health:
	@echo "PostgreSQL:" && docker-compose exec postgres pg_isready -U chatbot || echo "Not ready"
	@echo "Redis:" && docker-compose exec redis redis-cli ping || echo "Not ready"
	@echo "Rails:" && curl -f http://localhost:3000/health || echo "Not ready"