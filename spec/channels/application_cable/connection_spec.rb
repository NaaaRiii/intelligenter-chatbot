require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }

  describe '#connect' do
    context 'with valid authentication' do
      before do
        cookies.encrypted[:user_id] = user.id
      end

      it 'successfully connects and sets current_user' do
        connect '/cable'
        expect(connection.current_user).to eq(user)
      end
    end

    context 'without authentication' do
      it 'rejects connection' do
        expect { connect '/cable' }.to have_rejected_connection
      end
    end

    context 'with invalid user_id' do
      before do
        cookies.encrypted[:user_id] = 999_999
      end

      it 'rejects connection' do
        expect { connect '/cable' }.to have_rejected_connection
      end
    end
  end
end
