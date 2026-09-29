Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      String :email, null: false, unique: true
      String :password_hash, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table(:evaluations) do
      primary_key :id
      foreign_key :user_id, :users, null: false
      String :title, null: false
      String :stage, null: false, default: "briefing"
      Text :job_description
      Text :briefing_acknowledged_at
      Text :briefing_capability_list
      Boolean :web_search_available, default: false
      Boolean :code_execution_available, default: false
      Boolean :file_output_available, default: false
      Boolean :attachments_available, default: false
      Boolean :long_output_available, default: false
      Integer :current_weight_version, default: 0
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:user_id]
    end

    create_table(:kill_criteria) do
      primary_key :id
      foreign_key :evaluation_id, :evaluations, null: false
      String :name, null: false
      Text :description, null: false
      Integer :position, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:evaluation_id]
    end

    create_table(:drivers) do
      primary_key :id
      foreign_key :evaluation_id, :evaluations, null: false
      String :name, null: false
      Text :measures, null: false
      Text :how_evidenced, null: false
      Boolean :is_floor, default: false
      Integer :position, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:evaluation_id]
    end

    create_table(:weight_versions) do
      primary_key :id
      foreign_key :evaluation_id, :evaluations, null: false
      Integer :version_number, null: false
      String :weights_json, null: false # JSON hash: {driver_id: weight}
      String :floor_driver_ids, null: false # JSON array of driver IDs
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:evaluation_id, :version_number], unique: true
    end

    create_table(:human_gates) do
      primary_key :id
      foreign_key :evaluation_id, :evaluations, null: false
      String :name, null: false
      Text :question, null: false
      Integer :position, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:evaluation_id]
    end

    create_table(:candidates) do
      primary_key :id
      foreign_key :evaluation_id, :evaluations, null: false
      String :name, null: false
      String :label, null: false # e.g., "CANDIDATE 1"
      Text :cv_text_encrypted # AES-256 encrypted
      Text :tenure_line_json # JSON array of roles
      Text :kills # JSON array of strings
      Text :strengths # JSON array of strings
      Text :three_questions_json # JSON array of {question, tests}
      Text :recommendation
      Float :weighted_score
      Float :floor_score
      String :verdict # "pass", "reject", "ended"
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:evaluation_id]
    end

    create_table(:candidate_scores) do
      primary_key :id
      foreign_key :candidate_id, :candidates, null: false
      foreign_key :driver_id, :drivers, null: false
      Integer :score, null: false # 0-10
      String :mark, null: false # "V" or "I"
      Boolean :evidenced, default: false
      Text :justification
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:candidate_id, :driver_id], unique: true
    end

    create_table(:employers) do
      primary_key :id
      foreign_key :evaluation_id, :evaluations, null: false
      String :name, null: false
      String :legal_name
      String :trading_name
      Integer :footprint # 0-10
      String :turnover
      String :turnover_year
      String :turnover_currency
      String :turnover_source # "audited", "stated", "aggregator", "not_found"
      String :turnover_basis
      String :headcount
      String :headcount_source
      String :headcount_date
      String :function
      Text :claim_to_fame
      String :status # "trading", "distressed", "acquired", "defunct"
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:evaluation_id]
    end

    create_table(:employer_sources) do
      primary_key :id
      foreign_key :employer_id, :employers, null: false
      String :url, null: false
      DateTime :retrieved_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:employer_id]
    end

    create_table(:claims) do
      primary_key :id
      foreign_key :employer_id, :employers, null: false
      foreign_key :candidate_id, :candidates, null: false
      Text :cv_claim, null: false
      String :classification, null: false # CONFIRMED, CONTRADICTED, CANNOT_BE_FOUND, UNDERSTATED
      Text :search_description
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:employer_id, :candidate_id]
    end

    create_table(:score_movements) do
      primary_key :id
      foreign_key :candidate_id, :candidates, null: false
      foreign_key :driver_id, :drivers, null: false
      Integer :old_score, null: false
      Integer :new_score, null: false
      Text :reason, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:candidate_id]
    end

    create_table(:gate_marks) do
      primary_key :id
      foreign_key :candidate_id, :candidates, null: false
      foreign_key :human_gate_id, :human_gates, null: false
      String :mark, null: false # YES, NO, ?, NOT_REACHED
      Text :note
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:candidate_id, :human_gate_id], unique: true
    end

    create_table(:stage_runs) do
      primary_key :id
      foreign_key :evaluation_id, :evaluations, null: false
      Integer :stage_number, null: false
      String :status, null: false, default: "pending" # pending, running, completed, failed
      DateTime :started_at
      DateTime :completed_at
      Text :error_message
      Text :raw_request # JSON
      Text :raw_response # JSON
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:evaluation_id, :stage_number]
    end

    create_table(:disconfirmations) do
      primary_key :id
      foreign_key :evaluation_id, :evaluations, null: false
      foreign_key :driver_id, :drivers, null: false
      Text :evidence, null: false
      Boolean :accepted, default: false
      foreign_key :new_weight_version_id, :weight_versions
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:evaluation_id]
    end

    create_table(:reports) do
      primary_key :id
      foreign_key :evaluation_id, :evaluations, null: false
      String :issue_type, null: false # "pre_interview" or "post_interview"
      String :file_path, null: false
      DateTime :generated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:evaluation_id, :issue_type]
    end
  end
end
