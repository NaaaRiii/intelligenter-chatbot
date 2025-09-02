# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeBase, type: :model do
  describe 'associations' do
    it { should belong_to(:conversation).optional }
  end
  
  describe 'validations' do
    it { should validate_presence_of(:pattern_type) }
    it { should validate_presence_of(:content) }
    
    it 'validates success_score range' do
      kb = build(:knowledge_base, success_score: 101)
      expect(kb).not_to be_valid
      expect(kb.errors[:success_score]).to include('must be less than or equal to 100')
      
      kb.success_score = -1
      expect(kb).not_to be_valid
      expect(kb.errors[:success_score]).to include('must be greater than or equal to 0')
      
      kb.success_score = 85
      expect(kb).to be_valid
    end
    
    it 'validates pattern_type inclusion' do
      valid_types = ['successful_conversation', 'failed_conversation', 'best_practice', 'template']
      
      valid_types.each do |type|
        kb = build(:knowledge_base, pattern_type: type)
        expect(kb).to be_valid
      end
      
      kb = build(:knowledge_base, pattern_type: 'invalid_type')
      expect(kb).not_to be_valid
      expect(kb.errors[:pattern_type]).to include('is not included in the list')
    end
  end
  
  describe 'scopes' do
    before do
      create(:knowledge_base, pattern_type: 'successful_conversation', success_score: 90)
      create(:knowledge_base, pattern_type: 'successful_conversation', success_score: 60)
      create(:knowledge_base, pattern_type: 'failed_conversation', success_score: 30)
      create(:knowledge_base, pattern_type: 'best_practice', success_score: 85)
    end
    
    it 'filters by high score' do
      high_scored = KnowledgeBase.high_score
      expect(high_scored.count).to eq(2)
      expect(high_scored.pluck(:success_score)).to all(be >= 80)
    end
    
    it 'filters by pattern type' do
      successful = KnowledgeBase.by_type('successful_conversation')
      expect(successful.count).to eq(2)
      expect(successful.pluck(:pattern_type).uniq).to eq(['successful_conversation'])
    end
    
    it 'orders by success score' do
      ordered = KnowledgeBase.ordered_by_score
      scores = ordered.pluck(:success_score)
      expect(scores).to eq(scores.sort.reverse)
    end
  end
  
  describe 'methods' do
    let(:knowledge_base) { create(:knowledge_base) }
    
    describe '#successful?' do
      it 'returns true for high scores' do
        knowledge_base.success_score = 85
        expect(knowledge_base.successful?).to be true
      end
      
      it 'returns false for low scores' do
        knowledge_base.success_score = 45
        expect(knowledge_base.successful?).to be false
      end
    end
    
    describe '#add_tags' do
      it 'adds tags to the tags array' do
        knowledge_base.add_tags(['pricing', 'conversion'])
        expect(knowledge_base.tags).to include('pricing', 'conversion')
      end
      
      it 'prevents duplicate tags' do
        knowledge_base.tags = ['existing']
        knowledge_base.add_tags(['existing', 'new'])
        expect(knowledge_base.tags.count('existing')).to eq(1)
        expect(knowledge_base.tags).to include('new')
      end
    end
    
    describe '#extract_key_phrases' do
      it 'extracts important phrases from content' do
        knowledge_base.content = {
          'messages' => [
            { 'content' => '料金プランについて教えてください' },
            { 'content' => 'エンタープライズプランがおすすめです' }
          ]
        }
        
        phrases = knowledge_base.extract_key_phrases
        expect(phrases).to include('料金プラン')
        expect(phrases).to include('エンタープライズプラン')
      end
    end
    
    describe '#similarity_to' do
      let(:other_kb) { create(:knowledge_base) }
      
      it 'calculates similarity based on tags' do
        knowledge_base.tags = ['pricing', 'conversion', 'enterprise']
        other_kb.tags = ['pricing', 'conversion', 'support']
        
        similarity = knowledge_base.similarity_to(other_kb)
        expect(similarity).to be_between(0, 1)
        expect(similarity).to be > 0.5  # 2/3 tags match
      end
      
      it 'returns 0 for no matching tags' do
        knowledge_base.tags = ['pricing']
        other_kb.tags = ['support']
        
        expect(knowledge_base.similarity_to(other_kb)).to eq(0)
      end
    end
  end
  
  describe 'callbacks' do
    describe 'before_save' do
      it 'generates summary if not provided' do
        kb = build(:knowledge_base, summary: nil)
        kb.content = {
          'messages' => [
            { 'role' => 'user', 'content' => '導入を検討しています' },
            { 'role' => 'assistant', 'content' => 'どのような機能をお探しですか？' }
          ]
        }
        
        kb.save
        expect(kb.summary).to be_present
        expect(kb.summary).to include('導入検討')
      end
      
      it 'sets default metadata if not provided' do
        kb = build(:knowledge_base, metadata: nil)
        kb.save
        
        expect(kb.metadata).to be_a(Hash)
        expect(kb.metadata).to include('created_at')
        expect(kb.metadata).to include('version')
      end
    end
  end
  
  describe 'search functionality' do
    before do
      create(:knowledge_base, 
             summary: 'Customer asked about pricing plans',
             tags: ['pricing', 'plans'])
      create(:knowledge_base,
             summary: 'Support issue resolved successfully',
             tags: ['support', 'resolution'])
    end
    
    it 'searches by keyword in summary' do
      results = KnowledgeBase.search('pricing')
      expect(results.count).to eq(1)
      expect(results.first.summary).to include('pricing')
    end
    
    it 'searches by tags' do
      results = KnowledgeBase.with_tags(['support'])
      expect(results.count).to eq(1)
      expect(results.first.tags).to include('support')
    end
    
    it 'searches with multiple conditions' do
      results = KnowledgeBase.search('successfully').with_tags(['support'])
      expect(results.count).to eq(1)
      expect(results.first.tags).to include('support')
      expect(results.first.summary).to include('successfully')
    end
  end
end