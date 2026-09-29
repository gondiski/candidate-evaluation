class Plan < Sequel::Model
  plugin :validation_helpers
  
  one_to_many :subscriptions

  def validate
    super
    validates_presence [:name, :slug, :price_cents, :currency, :evaluations_per_month, :max_candidates]
    validates_unique :slug
    validates_includes %w[starter professional enterprise], :name
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

  def price
    price_cents / 100.0
  end

  def price_formatted
    "$#{'%.2f' % price}/#{billing_period}"
  end

  def billing_period
    "month"
  end

  def free?
    price_cents == 0
  end

  def enterprise?
    name == "enterprise"
  end

  def features
    features = []
    features << "#{evaluations_per_month == -1 ? 'Unlimited' : evaluations_per_month} evaluations/month"
    features << "#{max_candidates == -1 ? 'Unlimited' : max_candidates} candidates/evaluation"
    features << "Employer verification" if employer_verification
    features << "DOCX export" if docx_export
    features << "Priority support" if priority_support
    features
  end

  def self.starter
    find(slug: "starter")
  end

  def self.professional
    find(slug: "professional")
  end

  def self.enterprise
    find(slug: "enterprise")
  end
end
