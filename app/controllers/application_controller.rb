class ApplicationController < ActionController::API
  # テストでスタブされる前提のメソッドを最低限提供
  def current_user
    nil
  end

  def authenticate_user!
    true
  end
end
