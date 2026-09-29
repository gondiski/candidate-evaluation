class Evaluation < Sequel::Model
  plugin :validation_helpers
  plugin :json_serializer
  
  STAGES = %w[briefing job_description weights human_gates cvs verification pre_report diagnosis final_report].freeze
  
  STAGE_REQUIREMENTS = {
    "briefing" => [],
    "job_description" => ["briefing_acknowledged"],
    "weights" => ["job_description_present"],
    "human_gates" => ["weights_settled"],
    "cvs" => ["human_gates_present"],
    "verification" => ["candidates_present", "web_search_available"],
    "pre_report" => ["verification_complete"],
    "diagnosis" => ["pre_report_generated"],
    "final_report" => ["gate_marks_complete"]
  }.freeze

  many_to_one :user
  one_to_many :kill_criteria, class: :KillCriterion
  one_to_many :drivers
  one_to_many :weight_versions
  one_to_many :human_gates
  one_to_many :candidates
  one_to_many :employers
  one_to_many :stage_runs
  one_to_many :disconfirmations
  one_to_many :reports

  def validate
    super
    validates_presence [:user_id, :title, :stage]
    validates_includes STAGES, :stage
  end

  def before_create
    super
    self.stage = "briefing"
  end

  def before_update
    super
    self.updated_at = Sequel::CURRENT_TIMESTAMP
  end

  def current_weight_version_record
    weight_versions.where(version_number: current_weight_version).first
  end

  def weights_settled?
    current_weight_version > 0
  end

  def briefing_acknowledged?
    !briefing_acknowledged_at.nil?
  end

  def job_description_present?
    !job_description.nil? && !job_description.empty?
  end

  def human_gates_present?
    human_gates.count > 0
  end

  def candidates_present?
    candidates.count > 0
  end

  def verification_complete?
    employers.count > 0 && employers.all? { |e| e.researched? }
  end

  def pre_report_generated?
    reports.where(issue_type: "pre_interview").count > 0
  end

  def gate_marks_complete?
    return false if candidates.count == 0 || human_gates.count == 0
    candidates.all? do |candidate|
      human_gates.all? do |gate|
        !candidate.gate_mark_for(gate).nil?
      end
    end
  end

  def can_advance_to?(target_stage)
    target_index = STAGES.index(target_stage)
    current_index = STAGES.index(stage)
    return false unless target_index && current_index
    return false if target_index <= current_index
    
    # Check all requirements for stages up to target
    STAGES[0..target_index].each do |s|
      requirements = STAGE_REQUIREMENTS[s]
      requirements.each do |req|
        return false unless send("#{req}?") rescue false
      end
    end
    
    true
  end

  def advance_to!(target_stage)
    unless can_advance_to?(target_stage)
      unmet = unmet_requirements_for(target_stage)
      raise StageTransitionError, "Cannot advance to #{target_stage}. Unmet requirements: #{unmet.join(', ')}"
    end
    update(stage: target_stage)
  end

  def unmet_requirements_for(target_stage)
    unmet = []
    target_index = STAGES.index(target_stage)
    STAGES[0..target_index].each do |s|
      requirements = STAGE_REQUIREMENTS[s]
      requirements.each do |req|
        begin
          unmet << req unless send("#{req}?")
        rescue
          unmet << req
        end
      end
    end
    unmet
  end

  def latest_stage_run(stage_number)
    stage_runs.where(stage_number: stage_number).order(Sequel.desc(:created_at)).first
  end

  def candidate_by_label(label)
    candidates.where(label: label).first
  end

  def lock_key
    "evaluation_lock:#{id}"
  end

  def acquire_lock!
    acquired = REDIS.set(lock_key, "locked", nx: true, ex: 300)
    raise EvaluationLockedError, "Another stage is currently running" unless acquired
    true
  end

  def release_lock!
    REDIS.del(lock_key)
  end

  def update_progress(stage, detail = nil)
    REDIS.set("progress:#{id}", { stage: stage, detail: detail, updated_at: Time.now }.to_json, ex: 3600)
  end

  def progress
    data = REDIS.get("progress:#{id}")
    data ? JSON.parse(data) : { stage: stage, detail: nil, updated_at: nil }
  end

  def purge!
    DB.transaction do
      candidates.each(&:destroy)
      employers.each(&:destroy)
      kill_criteria.each(&:destroy)
      drivers.each(&:destroy)
      human_gates.each(&:destroy)
      weight_versions.each(&:destroy)
      disconfirmations.each(&:destroy)
      stage_runs.each(&:destroy)
      reports.each(&:destroy)
      destroy
    end
  end
end

class StageTransitionError < StandardError; end
class EvaluationLockedError < StandardError; end
