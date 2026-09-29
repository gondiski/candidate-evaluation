class Payment < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :subscription
  many_to_one :user

  def validate
    super
    validates_presence [:subscription_id, :user_id, :amount_cents, :currency, :status]
    validates_includes %w[pending completed failed refunded], :status
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

  def amount
    amount_cents / 100.0
  end

  def amount_formatted
    "$#{'%.2f' % amount}"
  end

  def completed?
    status == "completed"
  end

  def pending?
    status == "pending"
  end

  def failed?
    status == "failed"
  end

  def refunded?
    status == "refunded"
  end

  def mark_completed!(pesapal_data = {})
    update(
      status: "completed",
      paid_at: Sequel::CURRENT_TIMESTAMP,
      pesapal_payment_status: pesapal_data[:payment_status],
      pesapal_tracking_id: pesapal_data[:tracking_id],
      payment_method: pesapal_data[:payment_method],
      metadata: pesapal_data.to_json
    )
  end

  def mark_failed!(error_message = nil)
    update(
      status: "failed",
      metadata: { error: error_message }.to_json
    )
  end
end
