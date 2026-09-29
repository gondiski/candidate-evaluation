require "spec_helper"

RSpec.describe "Full Happy Path", type: :feature do
  let(:user) { create(:user, email: "test@example.com", password: "password123") }
  
  before do
    visit "/sessions/login"
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Login"
  end

  it "completes full evaluation flow" do
    # Create evaluation
    visit "/evaluations/new"
    fill_in "Title", with: "Test Evaluation"
    click_button "Create Evaluation"
    
    expect(page).to have_content("Test Evaluation")
    
    # Stage 1: Briefing
    within("li", text: "Briefing") do
      click_link "Start"
    end
    expect(page).to have_content("Briefing Text")
    click_button "Acknowledge and Run Capability Test"
    
    # Should redirect to evaluation page with briefing completed
    expect(page).to have_content("Briefing acknowledged")
    expect(page).to have_content("Completed")
  end
end
