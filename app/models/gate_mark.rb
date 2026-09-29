class GateMark < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :candidate
  many_to_one :human_gate

  MARKS = %w[YES NO ? NOT_REACHED].freeze

  def validate
    super
    validates_presence [:candidate_id, :human_gate_id, :mark]
    validates_includes MARKS, :mark
  end

  def before_create
    super
    self.created_at = Sequel::CURRENT_TIMESTAMP
    self.updated_at = Sequel::CURRENT_TIMESTAMP
  end

  def before_update
    super
    self.updated_at = Sequel::CURRENT_TIMESTAMP
  end

  def yes?
    mark == "YES"
  end

  def no?
    mark == "NO"
  end

  def uncertain?
    mark == "?"
  end

  def not_reached?
    mark == "NOT_REACHED"
  end
end
