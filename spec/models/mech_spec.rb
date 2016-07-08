require 'rails_helper'

RSpec.describe Mech, type: :model do
  before :each do
    @mech = Mech.new
  end
  it 'should be able to load master account information and crawl path' do
    expect(@mech.account[:username].blank?).to eq false
    expect(@mech.account[:password].blank?).to eq false

    expect(@mech.crawl.length).to be > 0
    @mech.crawl.each do |depts|
      expect(depts.length).to be > 0
    end
  end

  # it 'should be able to login' do
  #   @mech.login.select_term.select_department
  #   @mech.monitor course: 'EE-569', section: '30652 D'
  # end

  it 'should be able to load to database' do
    # @mech.login.select_term.select_department
    @mech.login.execute_crawl
    3.times do |i|
      puts "Reloading database iteration #{i + 1}"
      @mech.load_to_database
    end
  end
end
