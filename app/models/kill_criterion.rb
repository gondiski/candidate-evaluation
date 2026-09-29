class KillCriterion < Sequel::Model(:kill_criteria)
  plugin :validation_helpers
  
  many_to_one :evaluation

  def validate
    super
    validates_presence [:evaluation_id, :name, :description, :position]
  end
end
