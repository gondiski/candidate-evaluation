class VerifyEmployerJob
  include Sidekiq::Job
  
  sidekiq_options queue: :default, retry: 3

  def perform(evaluation_id, employer_id)
    evaluation = Evaluation[evaluation_id]
    employer = Employer[employer_id]
    return unless evaluation && employer
    
    # Build LLM client
    llm_client = LLM::AnthropicClient.new
    
    # Search for employer
    search_results = llm_client.web_search("#{employer.name} company")
    
    # Validate no candidate names in search
    candidate_names = evaluation.candidates.map(&:name)
    candidate_names.each do |name|
      if search_results.any? { |r| r[:query]&.include?(name) }
        raise "Search query must not contain candidate name"
      end
    end
    
    # Process results
    if search_results.any?
      # Store sources
      search_results.each do |result|
        EmployerSource.create(
          employer_id: employer.id,
          url: result[:url],
          retrieved_at: Sequel::CURRENT_TIMESTAMP
        )
      end
      
      # Update employer with research data
      # This would be more sophisticated in production
      employer.update(
        footprint: 5, # Default - would be determined by LLM
        status: "trading"
      )
    end
    
    # Update progress
    total = evaluation.employers.count
    done = evaluation.employers.select { |e| e.researched? }.count
    evaluation.update_progress("verification", "#{done}/#{total} employers researched")
    
  rescue => e
    logger.error("VerifyEmployerJob failed: #{e.message}")
    raise
  end
end
