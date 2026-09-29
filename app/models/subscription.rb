class Subscription < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :user
  many_to_one :plan
  one_to_many :payments

  def validate
    super
    validates_presence [:user_id, :plan_id, :status]
    validates_includes %w[active cancelled expired past_due], :status
  end

  def before_create
    super
    self.created_at = Sequel::CURRENT_TIMESTAMP
    self.updated_at = Sequel::CURRENT_TIMESTAMP
    self.current_period_start ||= Sequel::CURRENT_TIMESTAMP
    self.current_period_end ||= 30.days.from_now
  end

  def before_update
    super
    self.updated_at = Sequel::CURRENT_TIMESTAMP
  end

  def active?
    status == "active" && !expired?
  end

  def expired?
    current_period_end && current_period_end < Time.now
  end

  def cancelled?
    status == "cancelled"
  end

  def past_due?
    status == "past_due"
  end

  def cancel!
    update(status: "cancelled", cancelled_at: Sequel::CURRENT_TIMESTAMP)
  end

  def renew!
    update(
      status: "active",
      current_period_start: Sequel::CURRENT_TIMESTAMP,
      current_period_end: 30.days.from_now
    )
  end

  def evaluations_remaining
    return Float::INFINITY if plan.evaluuations_per_month == -1
    
    usage = EvaluationUsage.for_current_month(user_id)
    plan.evaluuations_per_month - (usage&.evaluations_count || 0)
  end

  def can_create_evaluation?
    return true if plan.evaluuations_per_month == -1
    evaluations_remaining > 0
  end

  def record_evaluation!
    usage = EvaluationUsage.find_or_create(user_id: user_id, year_month: current_year_month) do |u|
      u.evaluations_count = 0
    end
    usage.update(evaluations_count: usage.evaluations_count + 1)
  end

  private

  def current_year_month
    Time.now.strftime("%Y%m").to_i
  end
end
