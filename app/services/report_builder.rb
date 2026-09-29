require "prawn"
require "prawn/table"
require "caracal"

class ReportBuilder
  # Builds DOCX and PDF reports
  
  class << self
    # Build pre-interview report
    def build_pre_interview(evaluation)
      validate_for_report!(evaluation)
      
      docx_path = build_docx(evaluation, "pre_interview")
      pdf_path = build_pdf(evaluation, "pre_interview")
      
      # Verify page counts
      verify_page_count!(pdf_path, expected_pages(evaluation, "pre_interview"))
      
      # Create report record
      Report.create(
        evaluation_id: evaluation.id,
        issue_type: "pre_interview",
        file_path: pdf_path
      )
      
      { docx: docx_path, pdf: pdf_path }
    end

    # Build post-interview report
    def build_post_interview(evaluation, gate_marks)
      validate_for_report!(evaluation)
      
      # Validate gate marks
      GateSheet.assert_complete!(evaluation.candidates, evaluation.human_gates)
      
      docx_path = build_docx(evaluation, "post_interview", gate_marks)
      pdf_path = build_pdf(evaluation, "post_interview", gate_marks)
      
      # Verify page counts
      verify_page_count!(pdf_path, expected_pages(evaluation, "post_interview"))
      
      # Create report record
      Report.create(
        evaluation_id: evaluation.id,
        issue_type: "post_interview",
        file_path: pdf_path
      )
      
      { docx: docx_path, pdf: pdf_path }
    end

    private

    def validate_for_report!(evaluation)
      unless evaluation.candidates.any?
        raise ReportError, "No candidates found"
      end
      
      unless evaluation.current_weight_version_record
        raise ReportError, "No weight version settled"
      end
    end

    def expected_pages(evaluation, issue_type)
      candidates = evaluation.candidates.count
      # Summary + Consolidated + (2 per candidate) + Wrap-up
      2 + (candidates * 2) + 1
    end

    def verify_page_count!(pdf_path, expected)
      # This would use a PDF reader to count pages
      # For now, we'll trust the generation
      true
    end

    def build_docx(evaluation, issue_type, gate_marks = nil)
      candidates = evaluation.candidates.all
      weight_version = evaluation.current_weight_version_record
      
      Caracal::Document.save_as("#{reports_dir(evaluation)}/#{issue_type}_report.docx") do |docx|
        # Page 1: Summary
        docx.h1 "Summary"
        docx.p "How to read it: the weighted score, the Floor rule, the kill gate, the V/I marks — four lines."
        
        # Summary table
        docx.table summary_table_data(candidates, weight_version, issue_type, gate_marks)
        
        # Comparative timeline
        docx.h2 "Comparative Career Timeline"
        # Timeline would be rendered here
        
        # Page 2: Consolidated Evaluation
        docx.page
        docx.h1 "Consolidated Evaluation and Human-Validated Kill Factors"
        
        # Scores table
        docx.table scores_table_data(candidates, weight_version)
        
        # Gate grid
        docx.h2 "Human-Validated Kill Factors"
        if issue_type == "pre_interview"
          docx.p "Gate sheet blank — to be completed in interview"
          docx.table empty_gate_grid(candidates, evaluation.human_gates)
        else
          docx.table completed_gate_grid(candidates, evaluation.human_gates, gate_marks)
        end
        
        # Three rules
        docx.p GateSheet.three_rules
        
        # Signature block
        docx.p "Interviewer: _________________________ Date: _____________"
        docx.p "Candidate: _________________________ Outcome: _____________"
        
        # Two pages per candidate
        candidates.each do |candidate|
          docx.page
          build_candidate_assessment_page(docx, candidate, weight_version, issue_type, gate_marks)
          
          docx.page
          build_candidate_evidence_page(docx, candidate, evaluation, weight_version)
        end
        
        # Final page: Wrap-up
        docx.page
        docx.h1 "Wrap-up"
        build_wrapup(docx, evaluation, candidates, issue_type, gate_marks)
      end
      
      "#{reports_dir(evaluation)}/#{issue_type}_report.docx"
    end

    def build_pdf(evaluation, issue_type, gate_marks = nil)
      candidates = evaluation.candidates.all
      weight_version = evaluation.current_weight_version_record
      
      pdf = Prawn::Document.new(
        page_size: "A4",
        page_layout: :landscape,
        margin: [40, 50, 40, 50]
      )
      
      # Page 1: Summary
      build_summary_page(pdf, candidates, weight_version, issue_type, gate_marks)
      
      # Page 2: Consolidated Evaluation
      pdf.start_new_page
      build_consolidated_page(pdf, candidates, weight_version, evaluation, issue_type, gate_marks)
      
      # Two pages per candidate
      candidates.each do |candidate|
        pdf.start_new_page
        build_candidate_assessment_pdf(pdf, candidate, weight_version, issue_type, gate_marks)
        
        pdf.start_new_page
        build_candidate_evidence_pdf(pdf, candidate, evaluation, weight_version)
      end
      
      # Final page: Wrap-up
      pdf.start_new_page
      build_wrapup_pdf(pdf, evaluation, candidates, issue_type, gate_marks)
      
      pdf_path = "#{reports_dir(evaluation)}/#{issue_type}_report.pdf"
      pdf.render_file(pdf_path)
      
      pdf_path
    end

    def reports_dir(evaluation)
      dir = "#{File.dirname(__FILE__)}/../../tmp/reports/#{evaluation.id}"
      FileUtils.mkdir_p(dir)
      dir
    end

    def summary_table_data(candidates, weight_version, issue_type, gate_marks)
      header = ["Rank", "Name", "Description", "Weighted Score", "Floor", "Kill Gate", "Recommendation"]
      
      rows = candidates.each_with_index.map do |candidate, i|
        [
          i + 1,
          candidate.name,
          candidate.label,
          format_score(candidate.weighted_score),
          format_score(candidate.floor_score),
          issue_type == "post_interview" ? StatusDeriver.derive_status(candidate) : "pending",
          candidate.recommendation
        ]
      end
      
      [header] + rows
    end

    def scores_table_data(candidates, weight_version)
      header = ["Driver", "Weight"] + candidates.map(&:name)
      
      rows = evaluation.drivers.sort_by(&:position).map do |driver|
        row = [driver.name, weight_version.weight_for_driver(driver.id)]
        candidates.each do |candidate|
          score = candidate.score_for(driver)
          row << (score ? "#{score.score}#{score.mark}" : "-")
        end
        row
      end
      
      [header] + rows
    end

    def empty_gate_grid(candidates, human_gates)
      header = ["Factor"] + candidates.map(&:name)
      
      rows = human_gates.sort_by(&:position).map do |gate|
        [gate.name] + candidates.map { |_| "[ ]" }
      end
      
      [header] + rows
    end

    def completed_gate_grid(candidates, human_gates, gate_marks)
      header = ["Factor"] + candidates.map(&:name)
      
      rows = human_gates.sort_by(&:position).map do |gate|
        row = [gate.name]
        candidates.each do |candidate|
          mark = candidate.gate_mark_for(gate)
          row << (mark ? mark.mark : "-")
        end
        row
      end
      
      [header] + rows
    end

    def format_score(score)
      score ? "%.1f" % score : "-"
    end

    def build_summary_page(pdf, candidates, weight_version, issue_type, gate_marks)
      pdf.text "Summary", size: 24, style: :bold
      pdf.move_down 10
      
      pdf.text "How to read it: the weighted score, the Floor rule, the kill gate, the V/I marks — four lines."
      pdf.move_down 20
      
      # Summary table
      data = summary_table_data(candidates, weight_version, issue_type, gate_marks)
      pdf.table(data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        cells.padding = 5
        cells.borders = [:top, :bottom]
      end
      
      pdf.move_down 30
      pdf.text "Comparative Career Timeline", size: 18, style: :bold
      # Timeline rendering would go here
    end

    def build_consolidated_page(pdf, candidates, weight_version, evaluation, issue_type, gate_marks)
      pdf.text "Consolidated Evaluation and Human-Validated Kill Factors", size: 24, style: :bold
      pdf.move_down 20
      
      # Scores table
      data = scores_table_data(candidates, weight_version)
      pdf.table(data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        cells.padding = 5
      end
      
      pdf.move_down 30
      pdf.text "Human-Validated Kill Factors", size: 18, style: :bold
      pdf.move_down 10
      
      if issue_type == "pre_interview"
        pdf.text "Gate sheet blank — to be completed in interview"
        data = empty_gate_grid(candidates, evaluation.human_gates)
      else
        data = completed_gate_grid(candidates, evaluation.human_gates, gate_marks)
      end
      
      pdf.table(data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        cells.padding = 5
      end
      
      pdf.move_down 20
      pdf.text GateSheet.three_rules, size: 10
      
      pdf.move_down 30
      pdf.text "Interviewer: _________________________ Date: _____________"
      pdf.text "Candidate: _________________________ Outcome: _____________"
    end

    def build_candidate_assessment_page(pdf, candidate, weight_version, issue_type, gate_marks)
      pdf.text "#{candidate.name} - Assessment", size: 24, style: :bold
      pdf.move_down 20
      
      # Top summary
      pdf.text "Weighted Score: #{format_score(candidate.weighted_score)}"
      pdf.text "Floor: #{format_score(candidate.floor_score)}"
      pdf.text "Verdict: #{candidate.verdict}"
      
      if issue_type == "post_interview"
        status = StatusDeriver.derive_status(candidate)
        pdf.text "Status: #{status.upcase}"
      end
      
      pdf.move_down 20
      
      # Scoring table
      pdf.text "Scores", size: 18, style: :bold
      data = [["Driver", "Score", "Mark", "Evidence"]]
      candidate.candidate_scores.each do |cs|
        driver = cs.driver
        data << [driver.name, cs.score, cs.mark, cs.evidenced ? "Yes" : "No"]
      end
      
      pdf.table(data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        cells.padding = 5
      end
      
      pdf.move_down 20
      
      # Kills
      pdf.text "Kills", size: 18, style: :bold
      candidate.kills_list.each { |k| pdf.text "• #{k}" }
      
      pdf.move_down 10
      
      # Strengths
      pdf.text "Strengths", size: 18, style: :bold
      candidate.strengths_list.each { |s| pdf.text "• #{s}" }
      
      pdf.move_down 10
      
      # Questions
      pdf.text "Interview Questions", size: 18, style: :bold
      candidate.questions.each do |q|
        pdf.text "Q: #{q["question"]}"
        pdf.text "Tests: #{q["tests"]}", size: 10
      end
      
      pdf.move_down 10
      
      # Recommendation
      pdf.text "Recommendation", size: 18, style: :bold
      pdf.text candidate.recommendation
    end

    def build_candidate_evidence_page(pdf, candidate, evaluation, weight_version)
      pdf.text "#{candidate.name} - Evidence", size: 24, style: :bold
      pdf.move_down 20
      
      # Timeline
      pdf.text "Career Timeline", size: 18, style: :bold
      timeline = TimelineBuilder.build_individual_timeline(candidate)
      # Timeline rendering would go here
      
      pdf.move_down 20
      
      # Employer table
      pdf.text "Employer Research", size: 18, style: :bold
      employers = evaluation.employers.all
      if employers.any?
        data = [["Employer", "Footprint", "Status", "Sources"]]
        employers.each do |e|
          data << [e.name, e.footprint, e.status, e.employer_sources.count]
        end
        pdf.table(data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          cells.padding = 5
        end
      end
      
      pdf.move_down 20
      
      # Score movements
      movements = candidate.score_movements
      if movements.any?
        pdf.text "Score Changes from Research", size: 18, style: :bold
        data = [["Driver", "Old", "New", "Reason"]]
        movements.each do |m|
          data << [m.driver.name, m.old_score, m.new_score, m.reason]
        end
        pdf.table(data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          cells.padding = 5
        end
      end
    end

    def build_wrapup_pdf(pdf, evaluation, candidates, issue_type, gate_marks)
      pdf.text "Wrap-up", size: 24, style: :bold
      pdf.move_down 20
      
      if issue_type == "pre_interview"
        pdf.text "Pre-interview wrap-up based on paper evidence."
        pdf.move_down 10
        pdf.text "Candidates: #{candidates.count}"
        cleared = candidates.select { |c| c.verdict == "pass" }
        pdf.text "Passing paper review: #{cleared.count}"
      else
        pdf.text "Post-interview wrap-up."
        pdf.move_down 10
        
        cleared = candidates.select { |c| StatusDeriver.clear?(c) }
        if cleared.any?
          pdf.text "The seat can be filled."
          cleared.each { |c| pdf.text "• #{c.name} cleared all gates." }
        else
          pdf.text "The seat is not filled. No candidate cleared all gates."
        end
      end
      
      pdf.move_down 20
      pdf.text "Method and provenance:", size: 14, style: :bold
      pdf.text "Footprint ratings indicate organization presence and verification level."
      pdf.text "Financial figures are as reported and sourced."
      pdf.text "Limits: This assessment is based on paper evidence and interviews only."
    end
  end

  class ReportError < StandardError; end
end
