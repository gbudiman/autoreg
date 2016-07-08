class Section < ActiveRecord::Base
  belongs_to :course
  validates :course, presence: true
  validates :name, presence: true
end
