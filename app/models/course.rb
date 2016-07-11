class Course < ActiveRecord::Base
  has_many :sections, dependent: :destroy
  validates :code, presence: true
  validates :name, presence: true

  belongs_to :term
  validates :term, presence: true

  def self.search _x
    course = nil
    case _x
    when /([a-z]+)\-?(\d+)/i
      dept = $1.upcase
      course_id = $2

      search_string = "#{dept}-#{course_id}"
      courses = Course.joins(:term).where code: search_string
    end

    if courses == nil
      puts "#{search_string} does not exist"
    else
      courses.each do |course|
        course.denormalize_sections
      end
    end
  end

  def denormalize_sections 
    denorm = Array.new
    sections = Section.where course_id: self.id

    puts "#{self.code} - #{self.name} [#{self.term.name}]"
    
    sections.each do |section|
      result = Hash.new
      result[:section_name] = section.name
      result[:section_type] = section.cs_type
      result[:unit] = section.unit
      result[:registration] = humanize_registration(section)
      result[:time] = section.time
      result[:days] = section.days
      result[:location] = section.location
      denorm.push result
    end

    ap denorm
  end

private
  def humanize_registration _s
    case _s[:limit]
    when -1 then return 'Unknown'
    when -2 then return 'FULL'
    else
      return "#{_s[:registered]} / #{_s[:limit]}"
    end
  end
end
