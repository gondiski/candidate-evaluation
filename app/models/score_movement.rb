class ScoreMovement < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :candidate
  many_to_one :driver

  def validate
    super
    validates_presence [:candidate_id, :driver_id, :old_score, :new_score, :reason]
    validates_includes (0..10).to_a, :old_score
    validates_includes (0..10).to_a, :new_score
  end
end
