require 'rails_helper'

RSpec.describe Course, type: :model do
  it 'should be able to search a specific course' do
    Course.search 'ee569'
    Course.search 'csci580'
    Course.search 'csci574'
    Course.search 'ee450'
  end
end
