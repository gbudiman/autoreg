class Course < ActiveRecord::Base
  has_many :sections, dependent: :destroy
  validates :code, presence: true
  validates :name, presence: true

  def self.wipe
    Course.all.destroy
  end
end
