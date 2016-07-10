namespace :listing do
  task terms: :environment do
    Mech.new.login.list_terms
  end

  task :departments, [:term] => :environment do |task, args|
    Mech.new.login.select_term(args.term).list_departments
  end
end
