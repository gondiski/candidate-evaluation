Sequel.migration do
  change do
    create_table(:plans) do
      primary_key :id
      String :name, null: false # starter, professional, enterprise
      String :slug, null: false, unique: true
      Integer :price_cents, null: false # Price in cents
      String :currency, null: false, default: "USD"
      Integer :evaluations_per_month, null: false
      Integer :max_candidates, null: false
      Boolean :employer_verification, default: false
      Boolean :docx_export, default: false
      Boolean :priority_support, default: false
      Boolean :active, default: true
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table(:subscriptions) do
      primary_key :id
      foreign_key :user_id, :users, null: false
      foreign_key :plan_id, :plans, null: false
      String :status, null: false, default: "active" # active, cancelled, expired, past_due
      String :pesapal_subscription_id
      String :pesapal_merchant_reference
      DateTime :current_period_start
      DateTime :current_period_end
      DateTime :cancelled_at
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:user_id]
      index [:pesapal_subscription_id]
    end

    create_table(:payments) do
      primary_key :id
      foreign_key :subscription_id, :subscriptions, null: false
      foreign_key :user_id, :users, null: false
      Integer :amount_cents, null: false
      String :currency, null: false, default: "USD"
      String :status, null: false, default: "pending" # pending, completed, failed, refunded
      String :pesapal_order_id
      String :pesapal_payment_status
      String :pesapal_tracking_id
      String :payment_method
      DateTime :paid_at
      Text :metadata # JSON for additional data
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:subscription_id]
      index [:user_id]
      index [:pesapal_order_id]
    end

    create_table(:evaluation_usage) do
      primary_key :id
      foreign_key :user_id, :users, null: false
      Integer :year_month, null: false # YYYYMM format
      Integer :evaluations_count, default: 0
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:user_id, :year_month], unique: true
    end

    # Add subscription reference to users
    alter_table(:users) do
      add_column :subscription_status, String, default: "free" # free, active, cancelled
      add_column :trial_ends_at, DateTime
      add_column :pesapal_customer_id, String
    end
  end
end
