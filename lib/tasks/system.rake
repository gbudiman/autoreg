namespace :system do
  task rebuild: :environment do
    Term.destroy_all
    Mech.new.login.execute_crawl.load_to_database
  end
end
