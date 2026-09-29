class Report < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :evaluation

  ISSUE_TYPES = %w[pre_interview post_interview].freeze

  def validate
    super
    validates_presence [:evaluation_id, :issue_type, :file_path]
    validates_includes ISSUE_TYPES, :issue_type
  end

  def pre_interview?
    issue_type == "pre_interview"
  end

  def post_interview?
    issue_type == "post_interview"
  end
end
