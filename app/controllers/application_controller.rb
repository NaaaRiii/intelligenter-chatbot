class ApplicationController < ActionController::API
  # APIモードでもflashとビューレンダリングを有効化
  include ActionController::Flash
  include ActionController::Rendering
  include ActionView::Layouts
  include ActionController::ContentSecurityPolicy

  # ヘルパーメソッドを有効化
  helper_method :current_user

  # テストでスタブされる前提のメソッドを最低限提供
  def current_user
    nil
  end

  def authenticate_user!
    true
  end
end
