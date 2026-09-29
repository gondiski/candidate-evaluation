class RunStageJob
  include Sidekiq::Job
  
  sidekiq_options queue: :default, retry: 3

  def perform(evaluation_id, stage_number)
    evaluation = Evaluation[evaluation_id]
    return unless evaluation
    
    # Build LLM client
    llm_client = LLM::AnthropicClient.new
    
    # Run stage
    StageRunner.run_stage(evaluation, stage_number, llm_client)
  rescue => e
    # Log error
    logger.error("RunStageJob failed: #{e.message}")
    
    # Mark stage run as failed
    stage_run = evaluation&.stage_runs&.where(stage_number: stage_number)&.order(Sequel.desc(:created_at))&.first
    stage_run&.mark_failed!(e.message)
    
    raise # Re-raise for Sidekiq retry
  end
end
