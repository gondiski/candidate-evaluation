require "spec_helper"

RSpec.describe StatusDeriver do
  let(:evaluation) { create(:evaluation) }
  let(:candidate) { create(:candidate, evaluation: evaluation) }
  let(:gate1) { create(:human_gate, evaluation: evaluation, position: 0) }
  let(:gate2) { create(:human_gate, evaluation: evaluation, position: 1) }
  let(:gate3) { create(:human_gate, evaluation: evaluation, position: 2) }

  describe ".derive_status" do
    it "returns clear when all gates are YES" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate3, mark: "YES")

      expect(StatusDeriver.derive_status(candidate)).to eq("clear")
    end

    it "returns ended when any gate is NO" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "NO")
      create(:gate_mark, candidate: candidate, human_gate: gate3, mark: "YES")

      expect(StatusDeriver.derive_status(candidate)).to eq("ended")
    end

    it "returns open when any gate is ?" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "?")
      create(:gate_mark, candidate: candidate, human_gate: gate3, mark: "YES")

      expect(StatusDeriver.derive_status(candidate)).to eq("open")
    end

    it "returns open when any gate is NOT_REACHED" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "NOT_REACHED")
      create(:gate_mark, candidate: candidate, human_gate: gate3, mark: "YES")

      expect(StatusDeriver.derive_status(candidate)).to eq("open")
    end

    it "returns open when no marks exist" do
      expect(StatusDeriver.derive_status(candidate)).to eq("open")
    end
  end

  describe ".clear?" do
    it "returns true when all gates are YES" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "YES")

      expect(StatusDeriver.clear?(candidate)).to be true
    end

    it "returns false when any gate is not YES" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "?")

      expect(StatusDeriver.clear?(candidate)).to be false
    end
  end

  describe ".ended?" do
    it "returns true when any gate is NO" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "NO")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "YES")

      expect(StatusDeriver.ended?(candidate)).to be true
    end

    it "returns false when no gates are NO" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "?")

      expect(StatusDeriver.ended?(candidate)).to be false
    end
  end

  describe ".open?" do
    it "returns true when gates are unresolved" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "?")

      expect(StatusDeriver.open?(candidate)).to be true
    end

    it "returns false when all gates are resolved" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "YES")

      expect(StatusDeriver.open?(candidate)).to be false
    end
  end

  describe ".validate_marks!" do
    it "passes when ? is not converted to YES" do
      submitted = { "gate1" => "?" }
      report = { "gate1" => "?" }

      expect { StatusDeriver.validate_marks!(submitted, report) }.not_to raise_error
    end

    it "raises error when ? is converted to YES" do
      submitted = { "gate1" => "?" }
      report = { "gate1" => "YES" }

      expect { StatusDeriver.validate_marks!(submitted, report) }.to raise_error(StatusDeriver::GateMarkError)
    end
  end

  describe ".propagate_not_reached!" do
    it "sets remaining gates to NOT_REACHED after a NO" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "NO")
      create(:gate_mark, candidate: candidate, human_gate: gate3, mark: "YES")

      StatusDeriver.propagate_not_reached!(candidate, [gate1, gate2, gate3])

      expect(candidate.gate_mark_for(gate1).mark).to eq("YES")
      expect(candidate.gate_mark_for(gate2).mark).to eq("NO")
      expect(candidate.gate_mark_for(gate3).mark).to eq("NOT_REACHED")
    end
  end

  describe ".all_cells_filled?" do
    it "returns true when all cells are filled" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")
      create(:gate_mark, candidate: candidate, human_gate: gate2, mark: "NO")

      expect(StatusDeriver.all_cells_filled?(candidate, [gate1, gate2])).to be true
    end

    it "returns false when any cell is missing" do
      create(:gate_mark, candidate: candidate, human_gate: gate1, mark: "YES")

      expect(StatusDeriver.all_cells_filled?(candidate, [gate1, gate2])).to be false
    end
  end
end
