class CorrectionsController < ApplicationController
  before do
    authenticate!
  end

  # The six correction actions from the PDF
  CORRECTIONS = {
    "flattery" => {
      symptom: "It praises a candidate, or you.",
      meaning: "The honesty rule did not load, or it has drifted.",
      action: "You are flattering. Re-state that finding with the praise removed."
    },
    "weight_change" => {
      symptom: "It changes the weights after seeing a CV.",
      meaning: "It is tuning the instrument to the candidates.",
      action: "The weights are SETTLED. Score the candidate as they are and tell me what you tried to change."
    },
    "no_urls" => {
      symptom: "Verification with no URLs.",
      meaning: "It wrote Stage 6 from memory.",
      action: "Name the sources you retrieved, with URLs, for each company."
    },
    "fabricated" => {
      symptom: "'Could not find' becomes 'does not exist.'",
      meaning: "It has turned a search failure into an accusation.",
      action: "Restate that as what you searched and did not find. Not found is not the same as fabricated."
    },
    "one_number" => {
      symptom: "One number per candidate.",
      meaning: "The Floor rule was dropped.",
      action: "Give me the Floor alongside the weighted score for every candidate, and apply the cap."
    },
    "load_transfer" => {
      symptom: "It asks you to choose something it could decide.",
      meaning: "Load transfer.",
      action: "Decide it and tell me what you decided and why."
    }
  }.freeze

  get "/:evaluation_id" do
    @evaluation = load_evaluation
    @corrections = CORRECTIONS
    erb :"corrections/index"
  end

  post "/:evaluation_id/:correction_type" do
    @evaluation = load_evaluation
    correction = CORRECTIONS[params[:correction_type]]
    
    halt 400, "Invalid correction type" unless correction
    
    begin
      # Send correction to LLM in same session
      llm_client = build_llm_client
      
      # Build messages with correction context
      messages = [
        { role: "assistant", content: "Previous response from the evaluation." },
        { role: "user", content: correction[:action] }
      ]
      
      # Get system prompt
      system_prompt = PromptRenderer.briefing(@evaluation)
      
      # Call LLM
      response = llm_client.complete(
        system: system_prompt,
        messages: messages
      )
      
      # Store correction and response
      stage_run = StageRun.create(
        evaluation_id: @evaluation.id,
        stage_number: 0, # Special stage number for corrections
        status: "completed",
        started_at: Sequel::CURRENT_TIMESTAMP,
        completed_at: Sequel::CURRENT_TIMESTAMP,
        raw_request: { correction: params[:correction_type], action: correction[:action] }.to_json,
        raw_response: response[:raw].to_json
      )
      
      flash[:notice] = "Correction applied: #{correction[:symptom]}"
      redirect "/evaluations/#{@evaluation.id}"
    rescue => e
      flash[:error] = "Error applying correction: #{e.message}"
      redirect "/corrections/#{@evaluation.id}"
    end
  end

  private

  def load_evaluation
    evaluation = current_user.evaluations.where(id: params[:evaluation_id]).first
    halt 404, "Evaluation not found" unless evaluation
    evaluation
  end

  def build_llm_client
    if ENV["RACK_ENV"] == "test"
      LLM::FakeClient.new
    else
      LLM::AnthropicClient.new
    end
  end
end
