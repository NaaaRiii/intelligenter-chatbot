class DemoController < ApplicationController
  def components
    # デモページを表示
    render layout: false
  end
end