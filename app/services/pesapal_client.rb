require "httparty"
require "json"
require "logger"

module Pesapal
  class Client
    BASE_URL = ENV.fetch("PESAPAL_API_URL", "https://pay.pesapal.com/v3")
    
    def initialize
      @consumer_key = ENV.fetch("PESAPAL_CONSUMER_KEY")
      @consumer_secret = ENV.fetch("PESAPAL_CONSUMER_SECRET")
      @logger = Logger.new(STDOUT)
      @token = nil
      @token_expires_at = nil
    end

    # Get OAuth token
    def authenticate
      return @token if @token && @token_expires_at && @token_expires_at > Time.now
      
      response = HTTParty.post(
        "#{BASE_URL}/api/Auth/RequestToken",
        headers: { "Content-Type" => "application/json" },
        body: {
          consumer_key: @consumer_key,
          consumer_secret: @consumer_secret
        }.to_json
      )

      unless response.success?
        @logger.error("Pesapal auth failed: #{response.code} - #{response.body}")
        raise PesapalError, "Authentication failed"
      end

      data = JSON.parse(response.body)
      @token = data["token"]
      @token_expires_at = Time.now + (data["expiryDate"] ? Time.parse(data["expiryDate"]) - Time.now : 3600)
      @token
    end

    # Register IPN (Instant Payment Notification) URL
    def register_ipn(url, ipn_notification_type = "GET")
      authenticate
      
      response = HTTParty.post(
        "#{BASE_URL}/api/URLSetup/RegisterIPN",
        headers: auth_headers,
        body: {
          url: url,
          ipn_notification_type: ipn_notification_type
        }.to_json
      )

      unless response.success?
        @logger.error("Pesapal IPN registration failed: #{response.code} - #{response.body}")
        raise PesapalError, "IPN registration failed"
      end

      data = JSON.parse(response.body)
      data["ipn_id"]
    end

    # Submit order for payment
    def submit_order(order_data)
      authenticate
      
      response = HTTParty.post(
        "#{BASE_URL}/api/Transactions/SubmitOrderRequest",
        headers: auth_headers,
        body: order_data.to_json
      )

      unless response.success?
        @logger.error("Pesapal order submission failed: #{response.code} - #{response.body}")
        raise PesapalError, "Order submission failed"
      end

      data = JSON.parse(response.body)
      {
        order_tracking_id: data["order_tracking_id"],
        merchant_reference: data["merchant_reference"],
        redirect_url: data["redirect_url"],
        error: data["error"],
        status: data["status"]
      }
    end

    # Get transaction status
    def get_transaction_status(order_tracking_id)
      authenticate
      
      response = HTTParty.get(
        "#{BASE_URL}/api/Transactions/GetTransactionStatus?orderTrackingId=#{order_tracking_id}",
        headers: auth_headers
      )

      unless response.success?
        @logger.error("Pesapal status check failed: #{response.code} - #{response.body}")
        raise PesapalError, "Status check failed"
      end

      data = JSON.parse(response.body)
      {
        payment_status: data["payment_status_description"],
        tracking_id: data["payment_tracking_id"],
        status_code: data["status_code"],
        merchant_reference: data["merchant_reference"],
        payment_method: data["payment_method"],
        amount: data["amount"],
        currency: data["currency"]
      }
    end

    # Refund transaction
    def refund_transaction(order_tracking_id, amount, reason)
      authenticate
      
      response = HTTParty.post(
        "#{BASE_URL}/api/Transactions/RefundRequest",
        headers: auth_headers,
        body: {
          order_tracking_id: order_tracking_id,
          amount: amount,
          reason: reason
        }.to_json
      )

      unless response.success?
        @logger.error("Pesapal refund failed: #{response.code} - #{response.body}")
        raise PesapalError, "Refund failed"
      end

      data = JSON.parse(response.body)
      {
        status: data["status"],
        message: data["message"]
      }
    end

    private

    def auth_headers
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@token}"
      }
    end
  end

  class PesapalError < StandardError; end
end
