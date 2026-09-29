require "dotenv/load"
require_relative "config/environment"

run Rack::URLMap.new(
  "/" => ApplicationController,
  "/sessions" => SessionsController,
  "/evaluations" => EvaluationsController,
  "/stages" => StagesController,
  "/corrections" => CorrectionsController
)
