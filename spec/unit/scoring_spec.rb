require "spec_helper"

RSpec.describe Scoring do
  let(:evaluation) { create(:evaluation) }
  let(:driver1) { create(:driver, evaluation: evaluation, name: "Technical skills", is_floor: true, position: 0) }
  let(:driver2) { create(:driver, evaluation: evaluation, name: "Leadership", is_floor: false, position: 1) }
  let(:driver3) { create(:driver, evaluation: evaluation, name: "Communication", is_floor: true, position: 2) }
  let(:weight_version) { create(:weight_version, evaluation: evaluation, version_number: 1, weights_json: { driver1.id => 40, driver2.id => 30, driver3.id => 30 }.to_json, floor_driver_ids: [driver1.id.to_s, driver3.id.to_s].to_json) }
  let(:candidate) { create(:candidate, evaluation: evaluation) }

  describe ".weighted_score" do
    it "calculates weighted score correctly" do
      create(:candidate_score, candidate: candidate, driver: driver1, score: 8, evidenced: true)
      create(:candidate_score, candidate: candidate, driver: driver2, score: 6, evidenced: true)
      create(:candidate_score, candidate: candidate, driver: driver3, score: 7, evidenced: true)

      result = Scoring.weighted_score(candidate, weight_version)
      # (8*40 + 6*30 + 7*30) / 100 = (320 + 180 + 210) / 100 = 7.1
      expect(result).to eq(7.1)
    end

    it "applies evidence cap for non-evidenced scores" do
      create(:candidate_score, candidate: candidate, driver: driver1, score: 8, evidenced: false)
      create(:candidate_score, candidate: candidate, driver: driver2, score: 6, evidenced: true)
      create(:candidate_score, candidate: candidate, driver: driver3, score: 7, evidenced: true)

      result = Scoring.weighted_score(candidate, weight_version)
      # (3*40 + 6*30 + 7*30) / 100 = (120 + 180 + 210) / 100 = 5.1
      expect(result).to eq(5.1)
    end
  end

  describe ".floor_score" do
    it "returns lowest score among floor attributes" do
      create(:candidate_score, candidate: candidate, driver: driver1, score: 8, evidenced: true)
      create(:candidate_score, candidate: candidate, driver: driver2, score: 6, evidenced: true)
      create(:candidate_score, candidate: candidate, driver: driver3, score: 4, evidenced: true)

      result = Scoring.floor_score(candidate, weight_version)
      expect(result).to eq(4)
    end

    it "applies evidence cap to floor scores" do
      create(:candidate_score, candidate: candidate, driver: driver1, score: 8, evidenced: false)
      create(:candidate_score, candidate: candidate, driver: driver2, score: 6, evidenced: true)
      create(:candidate_score, candidate: candidate, driver: driver3, score: 4, evidenced: true)

      result = Scoring.floor_score(candidate, weight_version)
      # driver1 effective score is 3 (capped), driver3 is 4
      expect(result).to eq(3)
    end
  end

  describe ".verdict" do
    it "returns reject for floor <= 3" do
      expect(Scoring.verdict(3)).to eq("reject")
      expect(Scoring.verdict(2)).to eq("reject")
      expect(Scoring.verdict(1)).to eq("reject")
      expect(Scoring.verdict(0)).to eq("reject")
    end

    it "returns pass for floor > 3" do
      expect(Scoring.verdict(4)).to eq("pass")
      expect(Scoring.verdict(7)).to eq("pass")
      expect(Scoring.verdict(10)).to eq("pass")
    end
  end

  describe ".effective_score" do
    it "returns original score when evidenced" do
      expect(Scoring.effective_score(8, true)).to eq(8)
      expect(Scoring.effective_score(3, true)).to eq(3)
    end

    it "caps score at 3 when not evidenced" do
      expect(Scoring.effective_score(8, false)).to eq(3)
      expect(Scoring.effective_score(3, false)).to eq(3)
      expect(Scoring.effective_score(2, false)).to eq(2)
    end
  end

  describe ".valid_weights?" do
    it "returns true when weights sum to 100" do
      expect(Scoring.valid_weights?({ a: 50, b: 30, c: 20 })).to be true
    end

    it "returns false when weights don't sum to 100" do
      expect(Scoring.valid_weights?({ a: 50, b: 30, c: 10 })).to be false
    end
  end

  describe ".valid_score?" do
    it "returns true for valid scores" do
      (0..10).each do |score|
        expect(Scoring.valid_score?(score)).to be true
      end
    end

    it "returns false for invalid scores" do
      expect(Scoring.valid_score?(-1)).to be false
      expect(Scoring.valid_score?(11)).to be false
      expect(Scoring.valid_score?(5.5)).to be false
    end
  end

  describe ".valid_floor_count?" do
    it "returns true for 2-3 floor attributes" do
      expect(Scoring.valid_floor_count?(["1", "2"])).to be true
      expect(Scoring.valid_floor_count?(["1", "2", "3"])).to be true
    end

    it "returns false for invalid floor counts" do
      expect(Scoring.valid_floor_count?(["1"])).to be false
      expect(Scoring.valid_floor_count?(["1", "2", "3", "4"])).to be false
    end
  end

  describe ".score_band" do
    it "returns correct band descriptions" do
      expect(Scoring.score_band(0)).to eq("nothing on the page")
      expect(Scoring.score_band(2)).to eq("claimed but not evidenced")
      expect(Scoring.score_band(5)).to eq("evidenced, but adjacent, junior, or dated")
      expect(Scoring.score_band(7)).to eq("evidenced, current, at the level the job needs")
      expect(Scoring.score_band(9)).to eq("evidenced, and above the level — would raise the bar of the team they join")
    end
  end
end
