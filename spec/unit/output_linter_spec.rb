require "spec_helper"

RSpec.describe OutputLinter do
  describe ".lint" do
    it "flags sentences over 28 words" do
      text = "This is a very long sentence that goes on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on."
      
      flags = OutputLinter.lint(text)
      
      expect(flags.any? { |f| f[:type] == "sentence_length" }).to be true
    end

    it "does not flag short sentences" do
      text = "Short sentence. Another short one."
      
      flags = OutputLinter.lint(text)
      
      expect(flags.any? { |f| f[:type] == "sentence_length" }).to be false
    end

    it "flags praise/flattery words" do
      text = "The candidate has excellent skills and outstanding achievements."
      
      flags = OutputLinter.lint(text)
      
      expect(flags.any? { |f| f[:type] == "praise_flattery" }).to be true
    end

    it "flags fabricated usage for unfound claims" do
      text = "The company could not be found. The claim is fabricated and unsubstantiated."
      
      flags = OutputLinter.lint(text)
      
      expect(flags.any? { |f| f[:type] == "fabricated_usage" }).to be true
    end

    it "flags verified without URL" do
      text = "I verified the company exists."
      
      flags = OutputLinter.lint(text)
      
      expect(flags.any? { |f| f[:type] == "verified_no_url" }).to be true
    end

    it "does not flag verified with URL" do
      text = "I verified the company exists at https://example.com."
      
      flags = OutputLinter.lint(text)
      
      expect(flags.any? { |f| f[:type] == "verified_no_url" }).to be false
    end
  end

  describe ".flagged?" do
    it "returns true when content has flags" do
      text = "Excellent work by this outstanding candidate."
      
      expect(OutputLinter.flagged?(text)).to be true
    end

    it "returns false when content has no flags" do
      text = "The candidate meets the requirements."
      
      expect(OutputLinter.flagged?(text)).to be false
    end
  end

  describe ".flag_summary" do
    it "returns summary of all flags" do
      text = "Excellent verified without URL."
      
      summary = OutputLinter.flag_summary(text)
      
      expect(summary).to include("praise")
      expect(summary).to include("verified")
    end
  end
end
