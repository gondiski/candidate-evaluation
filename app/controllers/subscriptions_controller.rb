class SubscriptionsController < ApplicationController
  before do
    authenticate!
  end

  # Show subscription management page
  get "/" do
    @subscription = current_user.active_subscription
    @plan = @subscription&.plan
    @plans = Plan.where(active: true).order(:price_cents).all
    @payments = current_user.payments.order(Sequel.desc(:created_at)).limit(10).all
    erb :"subscriptions/index"
  end

  # Show new subscription page
  get "/new" do
    @plans = Plan.where(active: true).order(:price_cents).all
    @selected_plan = Plan.find(slug: params[:plan]) if params[:plan]
    erb :"subscriptions/new"
  end

  # Create subscription and initiate payment
  post "/create" do
    plan = Plan.find(id: params[:plan_id])
    halt 404, "Plan not found" unless plan

    # Check if user already has active subscription
    existing = current_user.active_subscription
    if existing && existing.active?
      flash[:error] = "You already have an active subscription."
      redirect "/subscriptions"
    end

    begin
      # Create subscription
      subscription = Subscription.create(
        user_id: current_user.id,
        plan_id: plan.id,
        status: "active",
        current_period_start: Sequel::CURRENT_TIMESTAMP,
        current_period_end: 30.days.from_now
      )

      if plan.free?
        # Free plan - no payment needed
        current_user.update(subscription_status: "active")
        flash[:notice] = "Subscribed to #{plan.name} plan."
        redirect "/subscriptions"
      else
        # Create payment record
        payment = Payment.create(
          subscription_id: subscription.id,
          user_id: current_user.id,
          amount_cents: plan.price_cents,
          currency: plan.currency,
          status: "pending"
        )

        # Submit to Pesapal
        pesapal = Pesapal::Client.new
        
        # Register IPN if not already done
        ipn_id = ENV["PESAPAL_IPN_ID"] || pesapal.register_ipn("#{ENV['APP_URL']}/subscriptions/callback")
        
        order_data = {
          id: payment.id.to_s,
          currency: plan.currency,
          amount: plan.price,
          description: "HRMLA #{plan.name.capitalize} Plan Subscription",
          callback_url: "#{ENV['APP_URL']}/subscriptions/callback",
          notification_id: ipn_id,
          billing_address: {
            email_address: current_user.email,
            first_name: current_user.email.split("@").first,
            last_name: ""
          }
        }

        result = pesapal.submit_order(order_data)
        
        # Update payment with Pesapal data
        payment.update(
          pesapal_order_id: result[:merchant_reference],
          status: "pending"
        )
        subscription.update(pesapal_merchant_reference: result[:merchant_reference])

        # Redirect to Pesapal payment page
        redirect result[:redirect_url]
      end
    rescue => e
      flash[:error] = "Error creating subscription: #{e.message}"
      redirect "/subscriptions/new"
    end
  end

  # Pesapal callback
  get "/callback" do
    order_tracking_id = params[:OrderTrackingId]
    merchant_reference = params[:OrderMerchantReference]
    
    unless order_tracking_id
      flash[:error] = "Invalid callback parameters."
      redirect "/subscriptions"
      return
    end

    begin
      pesapal = Pesapal::Client.new
      status = pesapal.get_transaction_status(order_tracking_id)
      
      payment = Payment.find(pesapal_order_id: merchant_reference)
      unless payment
        flash[:error] = "Payment not found."
        redirect "/subscriptions"
        return
      end

      if status[:payment_status] == "Completed"
        payment.mark_completed!(
          payment_status: status[:payment_status],
          tracking_id: status[:tracking_id],
          payment_method: status[:payment_method]
        )
        
        payment.subscription.update(status: "active")
        payment.user.update(subscription_status: "active")
        
        flash[:notice] = "Payment successful! Your subscription is now active."
      else
        payment.mark_failed!(status[:payment_status])
        flash[:error] = "Payment was not completed. Status: #{status[:payment_status]}"
      end

      redirect "/subscriptions"
    rescue => e
      flash[:error] = "Error processing payment: #{e.message}"
      redirect "/subscriptions"
    end
  end

  # Cancel subscription
  post "/cancel" do
    subscription = current_user.active_subscription
    
    unless subscription
      flash[:error] = "No active subscription found."
      redirect "/subscriptions"
      return
    end

    subscription.cancel!
    current_user.update(subscription_status: "cancelled")
    
    flash[:notice] = "Subscription cancelled. You can continue using your current plan until the end of the billing period."
    redirect "/subscriptions"
  end

  # Update subscription
  post "/update" do
    subscription = current_user.active_subscription
    new_plan = Plan.find(id: params[:plan_id])
    
    unless subscription && subscription.active?
      flash[:error] = "No active subscription found."
      redirect "/subscriptions"
      return
    end

    unless new_plan
      flash[:error] = "Invalid plan."
      redirect "/subscriptions"
      return
    end

    # Update subscription plan
    subscription.update(plan_id: new_plan.id)
    
    flash[:notice] = "Subscription updated to #{new_plan.name} plan."
    redirect "/subscriptions"
  end
end
