class StageRun < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :evaluation

  STATUSES = %w[pending running completed failed].freeze

  def validate
    super
    validates_presence [:evaluation_id, :stage_number, :status]
    validates_includes STATUSES, :status
  end

  def before_create
    super
    self.created_at = Sequel::CURRENT_TIMESTAMP
  end

  def mark_running!
    update(status: "running", started_at: Sequel::CURRENT_TIMESTAMP)
  end

  def mark_completed!(response_json)
    update(
      status: "completed",
      completed_at: Sequel::CURRENT_TIMESTAMP,
      raw_response: response_json.to_json
    )
  end

  def mark_failed!(error)
    update(
      status: "failed",
      completed_at: Sequel::CURRENT_TIMESTAMP,
      error_message: error.to_s
    )
  end

  def running?
    status == "running"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end
end
