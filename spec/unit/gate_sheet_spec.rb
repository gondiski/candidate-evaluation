require "spec_helper"

RSpec.describe GateSheet do
  let(:evaluation) { create(:evaluation) }
  let(:candidate) { create(:candidate, evaluation: evaluation) }
  let(:gate1) { create(:human_gate, evaluation: evaluation, position: 0) }
  let(:gate2) { create(:human_gate, evaluation: evaluation, position: 1) }

  describe ".valid_mark?" do
    it "returns true for valid marks" do
      expect(GateSheet.valid_mark?("YES")).to be true
      expect(GateSheet.valid_mark?("NO")).to be true
      expect(GateSheet.valid_mark?("?")).to be true
      expect(GateSheet.valid_mark?("NOT_REACHED")).to be true
    end

    it "returns false for invalid marks" do
      expect(GateSheet.valid_mark?("yes")).to be false
      expect(GateSheet.valid_mark?("PASS")).to be false
      expect(GateSheet.valid_mark?("")).to be false
    end
  end

  describe ".submit_marks!" do
    it "creates gate marks for all gates" do
      marks = { gate1.id.to_s => "YES", gate2.id.to_s => "NO" }

      GateSheet.submit_marks!(candidate, [gate1, gate2], marks)

      expect(candidate.gate_mark_for(gate1).mark).to eq("YES")
      expect(candidate.gate_mark_for(gate2).mark).to eq("NO")
    end

    it "raises error for blank cells" do
      marks = { gate1.id.to_s => "YES" }

      expect {
        GateSheet.submit_marks!(candidate, [gate1, gate2], marks)
      }.to raise_error(GateSheet::GateSheetError, /Blank cell/)
    end

    it "raises error for invalid marks" do
      marks = { gate1.id.to_s => "YES", gate2.id.to_s => "INVALID" }

      expect {
        GateSheet.submit_marks!(candidate, [gate1, gate2], marks)
      }.to raise_error(GateSheet::GateSheetError, /Invalid mark/)
    end

    it "prevents ? from being converted to YES" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "?")
      marks = { gate1.id.to_s => "YES", gate2.id.to_s => "NO" }

      expect {
        GateSheet.submit_marks!(candidate, [gate1, gate2], marks)
      }.to raise_error(GateSheet::GateSheetError, /cannot be converted/)
    end
  end

  describe ".empty_grid" do
    it "returns empty grid for candidates and gates" do
      grid = GateSheet.empty_grid([candidate], [gate1, gate2])

      expect(grid[candidate.id][gate1.id]).to eq("")
      expect(grid[candidate.id][gate2.id]).to eq("")
    end
  end

  describe ".completed_grid" do
    it "returns grid with actual marks" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "NO")

      grid = GateSheet.completed_grid([candidate], [gate1, gate2])

      expect(grid[candidate.id][gate1.id]).to eq("YES")
      expect(grid[candidate.id][gate2.id]).to eq("NO")
    end
  end

  describe ".three_rules" do
    it "returns the three rules text" do
      rules = GateSheet.three_rules

      expect(rules).to include("One FAIL ends the candidacy")
      expect(rules).to include("A blank is not a pass")
      expect(rules).to include("Both halves must clear")
    end
  end

  describe ".assert_empty!" do
    it "passes when all marks are empty" do
      expect { GateSheet.assert_empty!([candidate]) }.not_to raise_error
    end

    it "raises error when marks exist" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")

      expect { GateSheet.assert_empty!([candidate]) }.to raise_error(GateSheet::GateSheetError)
    end
  end

  describe ".assert_complete!" do
    it "passes when all cells are filled" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "NO")

      expect { GateSheet.assert_complete!([candidate], [gate1, gate2]) }.not_to raise_error
    end

    it "raises error when any cell is missing" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")

      expect { GateSheet.assert_complete!([candidate], [gate1, gate2]) }.to raise_error(GateSheet::GateSheetError)
    end
  end
end
