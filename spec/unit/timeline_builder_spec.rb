require "spec_helper"

RSpec.describe TimelineBuilder do
  describe ".parse_tenure_line" do
    it "parses tenure roles from JSON" do
      roles_json = [
        { "title" => "Developer", "company" => "Tech Corp", "start" => "2020-01", "end" => "2024-01" },
        { "title" => "Senior Developer", "company" => "Big Corp", "start" => "2024-02", "end" => "present" }
      ].to_json

      result = TimelineBuilder.parse_tenure_line(roles_json)

      expect(result.length).to eq(2)
      expect(result[0][:title]).to eq("Developer")
      expect(result[0][:assumed_start]).to be false
      expect(result[1][:title]).to eq("Senior Developer")
    end

    it "flags assumed mid-year dates" do
      roles_json = [
        { "title" => "Developer", "company" => "Tech Corp", "start" => "2020", "end" => "2024" }
      ].to_json

      result = TimelineBuilder.parse_tenure_line(roles_json)

      expect(result[0][:assumed_start]).to be true
      expect(result[0][:assumed_end]).to be true
    end
  end

  describe ".detect_concurrency" do
    it "detects concurrent roles" do
      roles = [
        { title: "Role A", start: Date.new(2020, 1, 1), end: Date.new(2022, 12, 31) },
        { title: "Role B", start: Date.new(2021, 6, 1), end: Date.new(2023, 6, 30) }
      ]

      result = TimelineBuilder.detect_concurrency(roles)

      expect(result.length).to eq(1)
      expect(result[0]).to eq(["Role A", "Role B"])
    end

    it "returns empty array for non-overlapping roles" do
      roles = [
        { title: "Role A", start: Date.new(2020, 1, 1), end: Date.new(2021, 12, 31) },
        { title: "Role B", start: Date.new(2022, 1, 1), end: Date.new(2023, 12, 31) }
      ]

      result = TimelineBuilder.detect_concurrency(roles)

      expect(result).to be_empty
    end
  end

  describe ".detect_gaps" do
    it "detects gaps between roles" do
      roles = [
        { title: "Role A", start: Date.new(2020, 1, 1), end: Date.new(2021, 12, 31) },
        { title: "Role B", start: Date.new(2022, 6, 1), end: Date.new(2023, 12, 31) }
      ]

      result = TimelineBuilder.detect_gaps(roles)

      expect(result.length).to eq(1)
      expect(result[0][:from]).to eq("Role A")
      expect(result[0][:to]).to eq("Role B")
      expect(result[0][:duration_months]).to eq(6)
    end

    it "returns empty array for continuous roles" do
      roles = [
        { title: "Role A", start: Date.new(2020, 1, 1), end: Date.new(2021, 12, 31) },
        { title: "Role B", start: Date.new(2022, 1, 1), end: Date.new(2023, 12, 31) }
      ]

      result = TimelineBuilder.detect_gaps(roles)

      expect(result).to be_empty
    end
  end

  describe ".calculate_duration_months" do
    it "calculates duration in months" do
      start_date = Date.new(2020, 1, 1)
      end_date = Date.new(2022, 6, 30)

      result = TimelineBuilder.calculate_duration_months(start_date, end_date)

      expect(result).to eq(29)
    end

    it "returns nil for nil dates" do
      expect(TimelineBuilder.calculate_duration_months(nil, Date.today)).to be_nil
      expect(TimelineBuilder.calculate_duration_months(Date.today, nil)).to be_nil
    end
  end

  describe ".format_duration" do
    it "formats years and months" do
      expect(TimelineBuilder.format_duration(30)).to eq("2 years, 6 months")
      expect(TimelineBuilder.format_duration(12)).to eq("1 year")
      expect(TimelineBuilder.format_duration(6)).to eq("6 months")
      expect(TimelineBuilder.format_duration(nil)).to eq("unknown")
    end
  end

  describe ".build_individual_timeline" do
    it "builds timeline for a candidate" do
      candidate = create(:candidate, tenure_line_json: [
        { "title" => "Developer", "start" => "2020-01", "end" => "2024-01" }
      ].to_json)

      result = TimelineBuilder.build_individual_timeline(candidate)

      expect(result[:roles].length).to eq(1)
      expect(result[:total_duration_months]).to eq(48)
    end
  end
end
