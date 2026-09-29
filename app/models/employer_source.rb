class EmployerSource < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :employer

  def validate
    super
    validates_presence [:employer_id, :url]
  end
end
