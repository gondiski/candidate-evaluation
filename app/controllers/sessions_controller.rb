class SessionsController < ApplicationController
  get "/login" do
    erb :"sessions/login"
  end

  post "/login" do
    user = User.first(email: params[:email])
    
    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      flash[:notice] = "Logged in successfully."
      redirect "/evaluations"
    else
      flash[:error] = "Invalid email or password."
      erb :"sessions/login"
    end
  end

  get "/register" do
    erb :"sessions/register"
  end

  post "/register" do
    user = User.new(email: params[:email])
    user.password = params[:password]
    
    begin
      if user.save
        session[:user_id] = user.id
        flash[:notice] = "Account created successfully."
        redirect "/evaluations"
      else
        flash[:error] = user.errors.full_messages.join(", ")
        erb :"sessions/register"
      end
    rescue Sequel::ValidationFailed => e
      flash[:error] = e.message
      erb :"sessions/register"
    end
  end

  get "/logout" do
    session.clear
    flash[:notice] = "Logged out."
    redirect "/sessions/login"
  end
end
