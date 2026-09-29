require "spec_helper"

RSpec.describe "Stage Guards" do
  let(:user) { create(:user) }
  
  before do
    login_as(user)
  end

  describe "stop gates" do
    it "enforces web search availability for verification" do
      evaluation = create(:evaluation, user: user, stage: "cvs", web_search_available: false)
      
      post "/stages/#{evaluation.id}/verification"
      
      # Should render the verification page with error
      expect(last_response).to be_ok
      expect(last_response.body).to include("Web search not available")
    end
  end
end
