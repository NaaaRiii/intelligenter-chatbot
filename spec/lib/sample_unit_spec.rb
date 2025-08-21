require 'spec_helper'

RSpec.describe 'Unit test without Rails' do
  it 'runs without database connection' do
    expect(1 + 1).to eq(2)
  end

  it 'demonstrates pure Ruby testing' do
    array = [1, 2, 3]
    expect(array.sum).to eq(6)
  end
end
