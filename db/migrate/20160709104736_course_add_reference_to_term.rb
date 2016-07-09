class CourseAddReferenceToTerm < ActiveRecord::Migration
  def change
    add_reference :courses, :term
  end
end
