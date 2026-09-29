class Driver < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :evaluation
  one_to_many :candidate_scores
  one_to_many :score_movements

  def validate
    super
    validates_presence [:evaluation_id, :name, :measures, :how_evidenced, :position]
  end

  def floor?
    is_floor == true
  end
end
