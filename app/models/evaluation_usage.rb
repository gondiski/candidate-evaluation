class EvaluationUsage < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :user

  def validate
    super
    validates_presence [:user_id, :year_month]
    validates_unique [:user_id, :year_month]
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

  def self.for_current_month(user_id)
    find(user_id: user_id, year_month: current_year_month)
  end

  def self.current_year_month
    Time.now.strftime("%Y%m").to_i
  end

  def self.increment!(user_id)
    usage = find_or_create(user_id: user_id, year_month: current_year_month) do |u|
      u.evaluations_count = 0
    end
    usage.update(evaluations_count: usage.evaluations_count + 1)
    usage
  end
end
