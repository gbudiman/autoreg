class Course < ActiveRecord::Base
  has_many :sections, dependent: :destroy
  validates :code, presence: true
  validates :name, presence: true

  belongs_to :term
  validates :term, presence: true

  def self.wipe
    Course.all.destroy
  end
end
