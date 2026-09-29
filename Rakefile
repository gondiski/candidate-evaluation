require "rake"
require "dotenv/load"
require_relative "config/environment"

namespace :db do
  desc "Run database migrations"
  task :migrate do
    Sequel.extension :migration
    Sequel::Migrator.run(DB, "db/migrate")
    puts "Migrations completed."
  end

  desc "Rollback last migration"
  task :rollback do
    Sequel.extension :migration
    Sequel::Migrator.run(DB, "db/migrate", target: -1)
    puts "Rollback completed."
  end

  desc "Seed the database"
  task :seed do
    require_relative "db/seeds"
    puts "Seeds completed."
  end

  desc "Reset database (drop, create, migrate, seed)"
  task :reset => [:migrate, :seed]
end

namespace :spec do
  desc "Run all tests"
  task :all do
    sh "bundle exec rspec"
  end
end

task :default do
  Rake::Task["spec:all"].invoke
end
