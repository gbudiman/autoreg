class CreateSections < ActiveRecord::Migration
  def change
    create_table :sections do |t|
      t.string        :name, null: false
      t.string        :cs_type, null: false
      t.integer       :unit
      t.integer       :registered
      t.integer       :limit
      t.string        :time
      t.string        :days
      t.string        :location

      t.belongs_to    :course, null: false

      t.timestamps    null: false
    end
  end
end
