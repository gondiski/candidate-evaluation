class Claim < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :employer
  many_to_one :candidate

  CLASSIFICATIONS = %w[CONFIRMED CONTRADICTED CANNOT_BE_FOUND UNDERSTATED].freeze

  def validate
    super
    validates_presence [:employer_id, :candidate_id, :cv_claim, :classification]
    validates_includes CLASSIFICATIONS, :classification
  end
end
