require "simplecov"
SimpleCov.start

require "dotenv/load"
ENV["RACK_ENV"] = "test"
ENV["SESSION_SECRET"] = "test_session_secret_that_is_long_enough_for_rack_session_requirements_64_chars"
ENV["CSRF_PROTECTION"] = "false"
require_relative "../config/environment"

require "rspec"
require "rack/test"
require "capybara/rspec"
require "webmock/rspec"
require "database_cleaner-sequel"
require "factory_bot"
require "faker"

# Load factories
require_relative "factories"

# Configure FactoryBot for Sequel
FactoryBot.define do
  to_create { |instance| instance.save }
end

# Disable external HTTP requests
WebMock.disable_net_connect!

# Configure Capybara
Capybara.app = Rack::Builder.new do
  map "/" do
    run ApplicationController
  end
  map "/sessions" do
    run SessionsController
  end
  map "/evaluations" do
    run EvaluationsController
  end
  map "/stages" do
    run StagesController
  end
  map "/corrections" do
    run CorrectionsController
  end
  map "/subscriptions" do
    run SubscriptionsController
  end
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include FactoryBot::Syntax::Methods
  config.include Capybara::DSL, type: :feature

  config.before(:suite) do
    DatabaseCleaner[:sequel].strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner[:sequel].start
  end

  config.after(:each) do
    DatabaseCleaner[:sequel].clean
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end

def app
  Capybara.app
end

def login_as(user)
  post "/sessions/login", email: user.email, password: "password123"
end
