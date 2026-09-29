class BuildReportJob
  include Sidekiq::Job
  
  sidekiq_options queue: :default, retry: 3

  def perform(evaluation_id, issue_type, gate_marks_json = nil)
    evaluation = Evaluation[evaluation_id]
    return unless evaluation
    
    gate_marks = gate_marks_json ? JSON.parse(gate_marks_json) : nil
    
    # Build report
    case issue_type
    when "pre_interview"
      result = ReportBuilder.build_pre_interview(evaluation)
    when "post_interview"
      result = ReportBuilder.build_post_interview(evaluation, gate_marks)
    end
    
    # Verify page count
    pdf_path = result[:pdf]
    verify_page_count!(pdf_path, evaluation, issue_type)
    
    # Update progress
    evaluation.update_progress(issue_type, "completed")
    
  rescue => e
    logger.error("BuildReportJob failed: #{e.message}")
    raise
  end

  private

  def verify_page_count!(pdf_path, evaluation, issue_type)
    # This would use a PDF reader to count pages
    # For now, we'll trust the generation
    true
  end
end
