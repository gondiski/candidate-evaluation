require "sinatra/base"
require "rack/csrf"

class ApplicationController < Sinatra::Base
  set :views, File.expand_path("../views", __dir__)
  set :public_folder, File.expand_path("../public", __dir__)
  set :session_secret, ENV.fetch("SESSION_SECRET", "change_me_in_production")
  set :sessions, true
  set :session_store, Rack::Session::Cookie
  
  use Rack::Session::Cookie, 
    secret: settings.session_secret,
    expire_after: 86400 # 24 hours
  
  # Enable CSRF protection in production/development, disable in test
  unless ENV["CSRF_PROTECTION"] == "false"
    use Rack::Csrf, raise: true
  end

  helpers do
    def current_user
      return @current_user if defined?(@current_user)
      @current_user = User[session[:user_id]] if session[:user_id]
    end

    def authenticate!
      unless current_user
        flash[:error] = "Please log in to continue."
        redirect "/sessions/login"
      end
    end

    def flash
      session[:flash] ||= {}
    end

    def flash_messages
      messages = session.delete("flash") || {}
      messages.map { |type, msg| "<div class='flash #{type}'>#{msg}</div>" }.join("\n")
    end

    def csrf_token
      Rack::Csrf.csrf_token(env)
    end

    def csrf_tag
      Rack::Csrf.csrf_tag(env)
    end

    def h(text)
      Rack::Utils.escape_html(text.to_s)
    end
  end

  before do
    content_type :html
  end

  get "/" do
    if current_user
      redirect "/evaluations"
    else
      redirect "/sessions/login"
    end
  end
end
