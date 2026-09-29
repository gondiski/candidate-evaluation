class StageRunner
  # Orchestrates stage execution with LLM calls
  
  class << self
    # Run a stage with the LLM
    def run_stage(evaluation, stage_number, llm_client)
      # Acquire lock
      evaluation.acquire_lock!
      
      begin
        # Create stage run record
        stage_run = StageRun.create(
          evaluation_id: evaluation.id,
          stage_number: stage_number,
          status: "running",
          started_at: Sequel::CURRENT_TIMESTAMP
        )
        
        evaluation.update_progress(stage_number, "starting")
        
        # Build system prompt with briefing
        system_prompt = build_system_prompt(evaluation)
        
        # Build stage-specific messages
        messages = build_messages(evaluation, stage_number)
        
        # Get schema if needed
        schema = stage_schema(stage_number)
        
        # Call LLM
        evaluation.update_progress(stage_number, "calling LLM")
        response = llm_client.complete(
          system: system_prompt,
          messages: messages,
          schema: schema
        )
        
        # Store raw request/response
        stage_run.raw_request = { system: system_prompt, messages: messages, schema: schema }.to_json
        stage_run.raw_response = response[:raw].to_json
        
        # Process response
        evaluation.update_progress(stage_number, "processing response")
        result = process_response(evaluation, stage_number, response[:content])
        
        stage_run.mark_completed!(response[:raw])
        evaluation.update_progress(stage_number, "completed")
        
        result
      rescue => e
        stage_run&.mark_failed!(e.message)
        evaluation.update_progress(stage_number, "failed: #{e.message}")
        raise
      ensure
        evaluation.release_lock!
      end
    end

    # Run capability self-test for briefing
    def run_capability_test(llm_client)
      results = {}
      
      # Test web search
      begin
        search_results = llm_client.web_search("test query")
        results[:web_search] = search_results.any?
      rescue
        results[:web_search] = false
      end
      
      # Test code execution
      results[:code_execution] = llm_client.code_execution_available?
      
      # Test file output
      results[:file_output] = llm_client.file_output_available?
      
      # Test attachments
      results[:attachments] = llm_client.attachments_available?
      
      # Test long output
      results[:long_output] = llm_client.long_output_available?
      
      results
    end

    private

    def build_system_prompt(evaluation)
      briefing = File.read("#{PROMPTS_DIR}/briefing.md.erb")
      ERB.new(briefing).result(binding)
    end

    def build_messages(evaluation, stage_number)
      case stage_number
      when 1 # Briefing
        [{ role: "user", content: "Acknowledge the briefing and declare your capabilities." }]
      when 2 # Job Description
        prompt = File.read("#{PROMPTS_DIR}/prompt_a.md.erb")
        [{ role: "user", content: "#{ERB.new(prompt).result(binding)}\n\n#{evaluation.job_description}" }]
      when 3 # Weights
        prompt = File.read("#{PROMPTS_DIR}/prompt_b.md.erb")
        [{ role: "user", content: ERB.new(prompt).result(binding) }]
      when 4 # Human Gates
        prompt = File.read("#{PROMPTS_DIR}/prompt_c.md.erb")
        [{ role: "user", content: ERB.new(prompt).result(binding) }]
      when 5 # CVs
        prompt = File.read("#{PROMPTS_DIR}/prompt_d.md.erb")
        cv_text = evaluation.candidates.map { |c| "#{c.label}: #{c.name}\n#{c.cv_text}" }.join("\n\n")
        [{ role: "user", content: "#{ERB.new(prompt).result(binding)}\n\n#{cv_text}" }]
      when 6 # Verification
        prompt = File.read("#{PROMPTS_DIR}/prompt_e.md.erb")
        [{ role: "user", content: ERB.new(prompt).result(binding) }]
      when 7 # Pre-report
        prompt = File.read("#{PROMPTS_DIR}/prompt_f.md.erb")
        [{ role: "user", content: ERB.new(prompt).result(binding) }]
      when 8 # Diagnosis
        prompt = File.read("#{PROMPTS_DIR}/prompt_g.md.erb")
        [{ role: "user", content: ERB.new(prompt).result(binding) }]
      when 9 # Final report
        prompt = File.read("#{PROMPTS_DIR}/prompt_h.md.erb")
        [{ role: "user", content: ERB.new(prompt).result(binding) }]
      else
        raise "Unknown stage: #{stage_number}"
      end
    end

    def stage_schema(stage_number)
      case stage_number
      when 1
        {
          type: "object",
          properties: {
            acknowledgement: { type: "string" },
            capabilities: {
              type: "object",
              properties: {
                web_search: { type: "boolean" },
                code_execution: { type: "boolean" },
                file_output: { type: "boolean" },
                attachments: { type: "boolean" },
                long_output: { type: "boolean" }
              }
            },
            affected_stages: { type: "array", items: { type: "integer" } }
          }
        }
      when 2
        {
          type: "object",
          properties: {
            kill_criteria: {
              type: "array",
              minItems: 3,
              maxItems: 5,
              items: {
                type: "object",
                properties: {
                  name: { type: "string" },
                  description: { type: "string" },
                  binary: { type: "boolean" }
                }
              }
            },
            drivers: {
              type: "array",
              minItems: 8,
              maxItems: 12,
              items: {
                type: "object",
                properties: {
                  name: { type: "string" },
                  measures: { type: "string" },
                  how_evidenced: { type: "string" }
                }
              }
            },
            load_bearing: { type: "array", items: { type: "string" } },
            inconsistencies: { type: "array", items: { type: "string" } },
            silences: { type: "array", items: { type: "string" } }
          }
        }
      when 3
        {
          type: "object",
          properties: {
            weights: { type: "object" },
            total: { type: "integer" },
            floor_attributes: { type: "array", items: { type: "string" } },
            scale: { type: "object" }
          }
        }
      when 4
        {
          type: "object",
          properties: {
            human_gates: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  name: { type: "string" },
                  question: { type: "string" }
                }
              }
            },
            note: { type: "string" }
          }
        }
      when 5
        {
          type: "object",
          properties: {
            candidates: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  name: { type: "string" },
                  tenure_line: { type: "array" },
                  kill_gate: { type: "array" },
                  scores: { type: "object" },
                  kills: { type: "array", items: { type: "string" } },
                  strengths: { type: "array", items: { type: "string" } },
                  questions: { type: "array" },
                  recommendation: { type: "string" }
                }
              }
            }
          }
        }
      when 6
        {
          type: "object",
          properties: {
            employers: { type: "array" },
            claims: { type: "array" },
            score_movements: { type: "array" }
          }
        }
      else
        nil
      end
    end

    def process_response(evaluation, stage_number, content)
      case stage_number
      when 1
        process_briefing(evaluation, content)
      when 2
        process_job_description(evaluation, content)
      when 3
        process_weights(evaluation, content)
      when 4
        process_human_gates(evaluation, content)
      when 5
        process_candidates(evaluation, content)
      when 6
        process_verification(evaluation, content)
      else
        content
      end
    end

    def process_briefing(evaluation, content)
      caps = content["capabilities"] || {}
      evaluation.update(
        briefing_acknowledged_at: Sequel::CURRENT_TIMESTAMP.to_s,
        briefing_capability_list: content.to_json,
        web_search_available: caps["web_search"] || false,
        code_execution_available: caps["code_execution"] || false,
        file_output_available: caps["file_output"] || false,
        attachments_available: caps["attachments"] || false,
        long_output_available: caps["long_output"] || false
      )
      content
    end

    def process_job_description(evaluation, content)
      # Validate counts
      kill_criteria = content["kill_criteria"] || []
      drivers = content["drivers"] || []
      
      unless kill_criteria.length >= 3 && kill_criteria.length <= 5
        raise "Kill criteria count must be 3-5, got #{kill_criteria.length}"
      end
      
      unless drivers.length >= 8 && drivers.length <= 12
        raise "Drivers count must be 8-12, got #{drivers.length}"
      end
      
      # Store kill criteria
      kill_criteria.each_with_index do |kc, i|
        KillCriterion.create(
          evaluation_id: evaluation.id,
          name: kc["name"],
          description: kc["description"],
          position: i
        )
      end
      
      # Store drivers
      load_bearing = content["load_bearing"] || []
      drivers.each_with_index do |d, i|
        Driver.create(
          evaluation_id: evaluation.id,
          name: d["name"],
          measures: d["measures"],
          how_evidenced: d["how_evidenced"],
          is_floor: load_bearing.include?(d["name"]),
          position: i
        )
      end
      
      content
    end

    def process_weights(evaluation, content)
      weights = content["weights"] || {}
      floor_names = content["floor_attributes"] || []
      
      # Validate weights sum to 100
      total = weights.values.sum
      unless total == 100
        raise "Weights must sum to 100, got #{total}"
      end
      
      # Validate floor count
      unless floor_names.length >= 2 && floor_names.length <= 3
        raise "Floor attributes must be 2-3, got #{floor_names.length}"
      end
      
      # Map driver names to IDs
      driver_map = {}
      evaluation.drivers.each { |d| driver_map[d.name] = d.id }
      
      weights_by_id = {}
      weights.each { |name, weight| weights_by_id[driver_map[name]] = weight }
      
      floor_ids = floor_names.map { |name| driver_map[name] }.compact
      
      # Create weight version
      version_number = evaluation.current_weight_version + 1
      WeightVersion.create(
        evaluation_id: evaluation.id,
        version_number: version_number,
        weights_json: weights_by_id.to_json,
        floor_driver_ids: floor_ids.to_json
      )
      
      evaluation.update(current_weight_version: version_number)
      
      content
    end

    def process_human_gates(evaluation, content)
      gates = content["human_gates"] || []
      
      # Validate no scores were attempted
      if content["scores"]
        raise "Human gates must not be scored"
      end
      
      gates.each_with_index do |gate, i|
        HumanGate.create(
          evaluation_id: evaluation.id,
          name: gate["name"],
          question: gate["question"],
          position: i
        )
      end
      
      content
    end

    def process_candidates(evaluation, content)
      candidates_data = content["candidates"] || []
      
      candidates_data.each_with_index do |cd, i|
        label = "CANDIDATE #{i + 1}"
        
        candidate = Candidate.create(
          evaluation_id: evaluation.id,
          name: cd["name"],
          label: label,
          tenure_line_json: cd["tenure_line"].to_json,
          kills: cd["kills"].to_json,
          strengths: cd["strengths"].to_json,
          three_questions_json: cd["questions"].to_json,
          recommendation: cd["recommendation"]
        )
        
        # Store scores
        weight_version = evaluation.current_weight_version_record
        scores = cd["scores"] || {}
        
        scores.each do |driver_name, score_data|
          driver = evaluation.drivers.find { |d| d.name == driver_name }
          next unless driver
          
          CandidateScore.create(
            candidate_id: candidate.id,
            driver_id: driver.id,
            score: score_data["score"],
            mark: score_data["mark"],
            evidenced: score_data["evidenced"] || false,
            justification: score_data["justification"]
          )
        end
        
        # Compute scores
        candidate.compute_scores!
      end
      
      content
    end

    def process_verification(evaluation, content)
      employers_data = content["employers"] || []
      claims_data = content["claims"] || []
      movements_data = content["score_movements"] || []
      
      # Store employers
      employers_data.each do |ed|
        employer = Employer.create(
          evaluation_id: evaluation.id,
          name: ed["name"],
          legal_name: ed["legal_name"],
          trading_name: ed["trading_name"],
          footprint: ed["footprint"],
          turnover: ed["turnover"],
          turnover_year: ed["turnover_year"],
          turnover_currency: ed["turnover_currency"],
          turnover_source: ed["turnover_source"],
          headcount: ed["headcount"],
          headcount_source: ed["headcount_source"],
          headcount_date: ed["headcount_date"],
          function: ed["function"],
          claim_to_fame: ed["claim_to_fame"],
          status: ed["status"]
        )
        
        # Store sources
        (ed["sources"] || []).each do |url|
          EmployerSource.create(
            employer_id: employer.id,
            url: url,
            retrieved_at: Sequel::CURRENT_TIMESTAMP
          )
        end
      end
      
      # Store claims
      claims_data.each do |cd|
        employer = evaluation.employers.find { |e| e.name == cd["employer"] }
        candidate = evaluation.candidates.find { |c| c.name == cd["candidate"] }
        
        if employer && candidate
          Claim.create(
            employer_id: employer.id,
            candidate_id: candidate.id,
            cv_claim: cd["cv_claim"],
            classification: cd["classification"],
            search_description: cd["search_description"]
          )
        end
      end
      
      # Store score movements
      movements_data.each do |md|
        candidate = evaluation.candidates.find { |c| c.name == md["candidate"] }
        driver = evaluation.drivers.find { |d| d.name == md["driver"] }
        
        if candidate && driver
          ScoreMovement.create(
            candidate_id: candidate.id,
            driver_id: driver.id,
            old_score: md["old"],
            new_score: md["new"],
            reason: md["reason"]
          )
        end
      end
      
      content
    end
  end
end
