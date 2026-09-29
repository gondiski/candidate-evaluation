require "spec_helper"

RSpec.describe "Authentication" do
  describe "GET /sessions/login" do
    it "renders login page" do
      get "/sessions/login"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("Login")
    end
  end

  describe "POST /sessions/login" do
    it "logs in with valid credentials" do
      user = create(:user, password: "password123")
      
      post "/sessions/login", email: user.email, password: "password123"
      
      expect(last_response).to be_redirect
      expect(last_response.location).to include("/evaluations")
    end

    it "rejects invalid credentials" do
      user = create(:user, password: "password123")
      
      post "/sessions/login", email: user.email, password: "wrongpassword"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("Invalid email or password")
    end
  end

  describe "GET /sessions/register" do
    it "renders registration page" do
      get "/sessions/register"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("Register")
    end
  end

  describe "POST /sessions/register" do
    it "creates new user with valid data" do
      post "/sessions/register", email: "new@example.com", password: "password123", password_confirmation: "password123"
      
      expect(last_response).to be_redirect
      expect(User.first(email: "new@example.com")).not_to be_nil
    end

    it "rejects invalid email" do
      post "/sessions/register", email: "invalid", password: "password123", password_confirmation: "password123"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("error")
    end
  end

  describe "GET /sessions/logout" do
    it "logs out user" do
      user = create(:user)
      login_as(user)
      
      get "/sessions/logout"
      
      expect(last_response).to be_redirect
      expect(last_response.location).to include("/sessions/login")
    end
  end
end
