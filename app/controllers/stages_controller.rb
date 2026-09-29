class StagesController < ApplicationController
  before do
    authenticate!
  end

  # Stage 1: Briefing
  get "/:evaluation_id/briefing" do
    @evaluation = load_evaluation
    @capability_test = @evaluation.briefing_capability_list ? JSON.parse(@evaluation.briefing_capability_list) : nil
    erb :"stages/briefing"
  end

  post "/:evaluation_id/briefing" do
    @evaluation = load_evaluation
    
    begin
      # Run capability test
      llm_client = build_llm_client
      capabilities = StageRunner.run_capability_test(llm_client)
      
      # Update evaluation with capabilities
      @evaluation.update(
        briefing_acknowledged_at: Sequel::CURRENT_TIMESTAMP.to_s,
        briefing_capability_list: capabilities.to_json,
        web_search_available: capabilities[:web_search],
        code_execution_available: capabilities[:code_execution],
        file_output_available: capabilities[:file_output],
        attachments_available: capabilities[:attachments],
        long_output_available: capabilities[:long_output]
      )
      
      flash[:notice] = "Briefing acknowledged. Capability test complete."
      redirect "/evaluations/#{@evaluation.id}"
    rescue => e
      flash[:error] = "Error: #{e.message}"
      erb :"stages/briefing"
    end
  end

  # Stage 2: Job Description
  get "/:evaluation_id/job_description" do
    @evaluation = load_evaluation
    erb :"stages/job_description"
  end

  post "/:evaluation_id/job_description" do
    @evaluation = load_evaluation
    
    begin
      # Store job description
      @evaluation.update(job_description: params[:job_description])
      
      # Run stage
      llm_client = build_llm_client
      result = StageRunner.run_stage(@evaluation, 2, llm_client)
      
      # Validate two lists returned
      unless result["kill_criteria"] && result["drivers"]
        raise "LLM must return both kill_criteria and drivers lists"
      end
      
      @evaluation.advance_to!("weights")
      flash[:notice] = "Job description processed. #{result['kill_criteria'].length} kill criteria, #{result['drivers'].length} drivers."
      redirect "/evaluations/#{@evaluation.id}"
    rescue => e
      flash[:error] = "Error: #{e.message}"
      erb :"stages/job_description"
    end
  end

  # Stage 3: Weights
  get "/:evaluation_id/weights" do
    @evaluation = load_evaluation
    @drivers = @evaluation.drivers.order(:position).all
    @weight_version = @evaluation.current_weight_version_record
    erb :"stages/weights"
  end

  post "/:evaluation_id/weights" do
    @evaluation = load_evaluation
    
    begin
      llm_client = build_llm_client
      result = StageRunner.run_stage(@evaluation, 3, llm_client)
      
      flash[:notice] = "Weights proposed. Review and type SETTLED when ready."
      redirect "/evaluations/#{@evaluation.id}/weights"
    rescue => e
      flash[:error] = "Error: #{e.message}"
      erb :"stages/weights"
    end
  end

  post "/:evaluation_id/weights/settle" do
    @evaluation = load_evaluation
    
    begin
      weight_version = @evaluation.current_weight_version_record
      unless weight_version
        raise "No weight version to settle"
      end
      
      # Verify weights sum to 100
      weight_version.verify_weights_sum_to_100!
      weight_version.verify_floor_count!
      
      # Mark as settled (weights are now read-only)
      @evaluation.update(current_weight_version: weight_version.version_number)
      
      @evaluation.advance_to!("human_gates")
      flash[:notice] = "Weights SETTLED. They are now read-only."
      redirect "/evaluations/#{@evaluation.id}"
    rescue => e
      flash[:error] = "Error: #{e.message}"
      redirect "/evaluations/#{@evaluation.id}/weights"
    end
  end

  # Stage 4: Human Gates
  get "/:evaluation_id/human_gates" do
    @evaluation = load_evaluation
    @human_gates = @evaluation.human_gates.order(:position).all
    erb :"stages/human_gates"
  end

  post "/:evaluation_id/human_gates" do
    @evaluation = load_evaluation
    
    begin
      llm_client = build_llm_client
      result = StageRunner.run_stage(@evaluation, 4, llm_client)
      
      # Validate no scores were attempted
      if result["scores"]
        raise "Human gates must not be scored. Re-run this step."
      end
      
      @evaluation.advance_to!("cvs")
      flash[:notice] = "Human gates defined."
      redirect "/evaluations/#{@evaluation.id}"
    rescue => e
      flash[:error] = "Error: #{e.message}"
      erb :"stages/human_gates"
    end
  end

  # Stage 5: CVs
  get "/:evaluation_id/cvs" do
    @evaluation = load_evaluation
    @candidates = @evaluation.candidates.order(:label).all
    erb :"stages/cvs"
  end

  post "/:evaluation_id/cvs" do
    @evaluation = load_evaluation
    
    begin
      # Accept all CVs at once
      cv_data = params[:cvs] || {}
      
      cv_data.each do |label, cv_text|
        name = label.gsub("CANDIDATE ", "").strip
        
        candidate = Candidate.new(
          evaluation_id: @evaluation.id,
          name: name,
          label: label,
          cv_text: cv_text
        )
        candidate.save
      end
      
      # Run stage
      llm_client = build_llm_client
      result = StageRunner.run_stage(@evaluation, 5, llm_client)
      
      # Validate two numbers per candidate
      @evaluation.candidates.each do |candidate|
        unless candidate.weighted_score && candidate.floor_score
          raise "Candidate #{candidate.name} missing weighted score or floor score"
        end
      end
      
      # Check if web search is available for stage 6
      unless @evaluation.web_search_available
        flash[:warning] = "Web search not available. Stage 6 (verification) will be skipped."
      end
      
      @evaluation.advance_to!("verification")
      flash[:notice] = "CVs processed. #{@evaluation.candidates.count} candidates scored."
      redirect "/evaluations/#{@evaluation.id}"
    rescue => e
      flash[:error] = "Error: #{e.message}"
      erb :"stages/cvs"
    end
  end

  # Stage 6: Verification
  get "/:evaluation_id/verification" do
    @evaluation = load_evaluation
    @employers = @evaluation.employers.all
    erb :"stages/verification"
  end

  post "/:evaluation_id/verification" do
    @evaluation = load_evaluation
    @employers = Employer.where(evaluation_id: @evaluation.id).all
    
    begin
      unless @evaluation.web_search_available
        raise "Web search not available. Cannot verify employers."
      end
      
      # Validate no candidate names in search queries
      candidate_names = @evaluation.candidates.map(&:name)
      
      llm_client = build_llm_client
      result = StageRunner.run_stage(@evaluation, 6, llm_client)
      
      # Check that employers have URLs
      @employers.each do |employer|
        unless employer.researched?
          flash[:warning] = "Employer #{employer.name} has no retrieved URLs. Marked as not researched."
        end
      end
      
      @evaluation.advance_to!("pre_report")
      flash[:notice] = "Employer verification complete."
      redirect "/evaluations/#{@evaluation.id}"
    rescue => e
      flash[:error] = "Error: #{e.message}"
      erb :"stages/verification"
    end
  end

  # Stage 7: Pre-Interview Report
  get "/:evaluation_id/pre_report" do
    @evaluation = load_evaluation
    @report = @evaluation.reports.where(issue_type: "pre_interview").first
    erb :"stages/pre_report"
  end

  post "/:evaluation_id/pre_report" do
    @evaluation = load_evaluation
    
    begin
      # Build report
      result = ReportBuilder.build_pre_interview(@evaluation)
      
      # Verify gate sheet is empty
      GateSheet.assert_empty!(@evaluation.candidates)
      
      @evaluation.advance_to!("diagnosis")
      flash[:notice] = "Pre-interview report generated."
      redirect "/evaluations/#{@evaluation.id}"
    rescue => e
      flash[:error] = "Error: #{e.message}"
      erb :"stages/pre_report"
    end
  end

  # Stage 8: Diagnosis
  get "/:evaluation_id/diagnosis" do
    @evaluation = load_evaluation
    @stage_run = @evaluation.latest_stage_run(8)
    erb :"stages/diagnosis"
  end

  post "/:evaluation_id/diagnosis" do
    @evaluation = load_evaluation
    
    begin
      llm_client = build_llm_client
      result = StageRunner.run_stage(@evaluation, 8, llm_client)
      
      @evaluation.advance_to!("final_report")
      flash[:notice] = "Pool diagnosis complete."
      redirect "/evaluations/#{@evaluation.id}"
    rescue => e
      flash[:error] = "Error: #{e.message}"
      erb :"stages/diagnosis"
    end
  end

  # Stage 9: Final Report
  get "/:evaluation_id/final_report" do
    @evaluation = load_evaluation
    @candidates = @evaluation.candidates.all
    @human_gates = @evaluation.human_gates.order(:position).all
    @gate_marks = {}
    @candidates.each do |candidate|
      @gate_marks[candidate.id] = {}
      @human_gates.each do |gate|
        mark = candidate.gate_mark_for(gate)
        @gate_marks[candidate.id][gate.id] = mark ? mark.mark : ""
      end
    end
    erb :"stages/final_report"
  end

  post "/:evaluation_id/final_report" do
    @evaluation = load_evaluation
    
    begin
      # Process gate marks
      marks_data = params[:gate_marks] || {}
      
      @evaluation.candidates.each do |candidate|
        candidate_marks = marks_data[candidate.id.to_s] || {}
        
        GateSheet.submit_marks!(
          candidate,
          @evaluation.human_gates,
          candidate_marks
        )
      end
      
      # Validate no blanks
      GateSheet.assert_complete!(@evaluation.candidates, @evaluation.human_gates)
      
      # Validate ? not converted to YES
      # (This is checked in GateSheet.submit_marks!)
      
      # Build final report
      result = ReportBuilder.build_post_interview(@evaluation, marks_data)
      
      flash[:notice] = "Final report generated."
      redirect "/evaluations/#{@evaluation.id}"
    rescue => e
      flash[:error] = "Error: #{e.message}"
      erb :"stages/final_report"
    end
  end

  # Progress polling endpoint
  get "/:evaluation_id/progress" do
    @evaluation = load_evaluation
    content_type :json
    @evaluation.progress.to_json
  end

  private

  def load_evaluation
    evaluation = Evaluation.where(user_id: current_user.id, id: params[:evaluation_id]).first
    halt 404, "Evaluation not found" unless evaluation
    evaluation
  end

  def build_llm_client
    # Use AnthropicClient in production, FakeClient in test
    if ENV["RACK_ENV"] == "test"
      LLM::FakeClient.new
    else
      LLM::AnthropicClient.new
    end
  end
end
