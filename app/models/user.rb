require "bcrypt"

class User < Sequel::Model
  plugin :validation_helpers
  
  one_to_many :evaluations

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
end
