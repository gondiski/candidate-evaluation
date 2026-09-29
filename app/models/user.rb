require "bcrypt"

class User < Sequel::Model
  plugin :validation_helpers
  
  one_to_many :evaluations
  one_to_many :subscriptions
  one_to_many :payments

  def validate
    super
    validates_presence [:email, :password_hash]
    validates_unique :email
    validates_format(/\A[^@\s]+@[^@\s]+\z/, :email, message: "is not a valid email")
  end

  def password=(new_password)
    self.password_hash = BCrypt::Password.create(new_password)
  end

  def authenticate(test_password)
    BCrypt::Password.new(password_hash) == test_password
  end

  def active_subscription
    subscriptions.where(status: "active").order(Sequel.desc(:created_at)).first
  end

  def current_plan
    active_subscription&.plan || Plan.starter
  end

  def can_create_evaluation?
    subscription = active_subscription
    return true unless subscription # Free plan allows limited evaluations
    subscription.can_create_evaluation?
  end

  def evaluations_remaining
    subscription = active_subscription
    return 2 unless subscription # Free plan: 2 evaluations
    subscription.evaluations_remaining
  end

  def subscription_active?
    subscription_status == "active" || subscription_status == "free"
  end
end
