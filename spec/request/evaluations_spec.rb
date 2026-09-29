require "spec_helper"

RSpec.describe "Evaluations" do
  let(:user) { create(:user) }
  
  before do
    login_as(user)
  end

  describe "GET /evaluations" do
    it "lists user's evaluations" do
      eval1 = create(:evaluation, user: user, title: "Eval 1")
      eval2 = create(:evaluation, user: user, title: "Eval 2")
      
      get "/evaluations"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("Eval 1")
      expect(last_response.body).to include("Eval 2")
    end

    it "does not show other users' evaluations" do
      other_user = create(:user)
      other_eval = create(:evaluation, user: other_user, title: "Other Eval")
      
      get "/evaluations"
      
      expect(last_response.body).not_to include("Other Eval")
    end
  end

  describe "POST /evaluations" do
    it "creates new evaluation" do
      post "/evaluations", title: "New Evaluation"
      
      expect(last_response).to be_redirect
      expect(Evaluation.where(user_id: user.id, title: "New Evaluation").first).not_to be_nil
    end
  end

  describe "GET /evaluations/:id" do
    it "shows evaluation details" do
      evaluation = create(:evaluation, user: user)
      
      get "/evaluations/#{evaluation.id}"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include(evaluation.title)
    end

    it "returns 404 for non-existent evaluation" do
      get "/evaluations/999999"
      
      expect(last_response.status).to eq(404)
    end
  end

  describe "DELETE /evaluations/:id" do
    it "purges evaluation and all data" do
      evaluation = create(:evaluation, user: user)
      create(:candidate, evaluation: evaluation)
      
      delete "/evaluations/#{evaluation.id}"
      
      expect(last_response).to be_redirect
      expect(Evaluation[evaluation.id]).to be_nil
    end
  end
end
