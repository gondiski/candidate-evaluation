class HumanGate < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :evaluation
  one_to_many :gate_marks

  def validate
    super
    validates_presence [:evaluation_id, :name, :question, :position]
  end
end
