require "sinatra/base"
require "sequel"
require "bcrypt"
require "rack/csrf"
require "zeitwerk"
require "logger"
require "json"
require "erb"
require "sidekiq"
require "redis"

# Load environment variables
begin
  Dotenv.load
rescue
  # Dotenv not loaded, continue
end

# Database connection
DB = Sequel.connect(ENV.fetch("DATABASE_URL", "postgres://localhost:5432/hrmla_test"))

# Redis connection for Sidekiq and live progress
REDIS = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))

# Sidekiq configuration
Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

# Zeitwerk autoloader
loader = Zeitwerk::Loader.new
loader.push_dir("#{__dir__}/../app/models")
loader.push_dir("#{__dir__}/../app/services")
loader.push_dir("#{__dir__}/../app/jobs")
loader.push_dir("#{__dir__}/../app/controllers")
loader.push_dir("#{__dir__}/../app/llm")
loader.inflector.inflect("llm" => "LLM")
loader.setup

# Load prompts
PROMPTS_DIR = "#{__dir__}/../app/prompts"

# Load LLM module explicitly
require_relative "../app/llm/client"
require_relative "../app/llm/anthropic_client"
require_relative "../app/llm/fake_client"
