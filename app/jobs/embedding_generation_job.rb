# frozen_string_literal: true

# メッセージのembeddingを非同期で生成するジョブ
class EmbeddingGenerationJob < ApplicationJob
  queue_as :default
  
  # リトライ設定
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  def perform(message_id)
    message = Message.find_by(id: message_id)
    
    if message.nil?
      Rails.logger.warn "Message with ID #{message_id} not found for embedding generation"
      return
    end
    
    # 既にembeddingが存在する場合はスキップ
    if message.has_embedding?
      Rails.logger.debug "Message #{message_id} already has embedding, skipping"
      return
    end
    
    Rails.logger.info "Generating embedding for message #{message_id}"
    
    # VectorSearchServiceを使用してembeddingを生成
    vector_service = VectorSearchService.new
    success = vector_service.store_message_embedding(message)
    
    if success
      Rails.logger.info "Successfully generated embedding for message #{message_id}"
      
      # メタデータに生成情報を記録
      message.add_metadata('embedding_generated_at', Time.current.to_s)
      message.add_metadata('embedding_generation_job_id', job_id) if respond_to?(:job_id)
    else
      Rails.logger.error "Failed to generate embedding for message #{message_id}"
      raise StandardError, "Embedding generation failed for message #{message_id}"
    end
    
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Message not found during embedding generation: #{e.message}"
    raise # ジョブを失敗させてリトライを停止
    
  rescue StandardError => e
    Rails.logger.error "Embedding generation error for message #{message_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
    raise # リトライを有効にするためにraiseする
  end
end