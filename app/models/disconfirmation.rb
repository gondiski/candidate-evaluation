class Disconfirmation < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :evaluation
  many_to_one :driver
  many_to_one :new_weight_version, class: :WeightVersion

  def validate
    super
    validates_presence [:evaluation_id, :driver_id, :evidence]
  end

  def accept!
    DB.transaction do
      # Create new weight version with adjusted weights
      old_version = evaluation.current_weight_version_record
      new_version_number = old_version.version_number + 1
      
      # Create new weight version (weights adjusted by user)
      # This is handled by the controller/service
      update(accepted: true)
    end
  end

  def dismiss!
    update(accepted: false)
  end
end
