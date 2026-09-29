require "json"

module LLM
  class FakeClient < Client
    attr_accessor :responses, :search_results

    def initialize
      @responses = {}
      @search_results = []
      @call_count = 0
    end

    def complete(system:, messages:, schema: nil, tools: nil)
      @call_count += 1
      
      # Return pre-configured response or default
      response = @responses[@call_count] || default_response(system, messages, schema)
      
      {
        content: response,
        usage: { "input_tokens" => 100, "output_tokens" => 200 },
        raw: { "id" => "fake_#{@call_count}", "content" => [{ "type" => "text", "text" => response.to_s }] }
      }
    end

    def web_search(query)
      @search_results
    end

    def web_search_available?
      true
    end

    def code_execution_available?
      true
    end

    def file_output_available?
      true
    end

    def attachments_available?
      true
    end

    def long_output_available?
      true
    end

    def reset!
      @responses = {}
      @search_results = []
      @call_count = 0
    end

    private

    def default_response(system, messages, schema)
      # Return appropriate default based on system prompt content
      if system.include?("Briefing") || system.include?("capability")
        briefing_response
      elsif system.include?("job description") || system.include?("Kill criteria")
        job_description_response
      elsif system.include?("weights") || system.include?("scoring table")
        weights_response
      elsif system.include?("human") || system.include?("kill factor")
        human_gates_response
      elsif system.include?("CV") || system.include?("candidate")
        cv_response
      elsif system.include?("verify") || system.include?("employer")
        verification_response
      elsif system.include?("report")
        report_response
      else
        { "content" => "Default response" }
      end
    end

    def briefing_response
      {
        "acknowledgement" => "I have read and understood the briefing.",
        "capabilities" => {
          "web_search" => true,
          "code_execution" => true,
          "file_output" => true,
          "attachments" => true,
          "long_output" => true
        },
        "affected_stages" => []
      }
    end

    def job_description_response
      {
        "kill_criteria" => [
          { "name" => "Degree requirement", "description" => "Must have a relevant degree", "binary" => true },
          { "name" => "Years experience", "description" => "Must have 5+ years experience", "binary" => true },
          { "name" => "Industry background", "description" => "Must have relevant industry background", "binary" => true }
        ],
        "drivers" => [
          { "name" => "Technical skills", "measures" => "Depth of technical expertise", "how_evidenced" => "Projects, certifications, work examples" },
          { "name" => "Leadership", "measures" => "Ability to lead teams", "how_evidenced" => "Team size, outcomes, promotions" },
          { "name" => "Communication", "measures" => "Written and verbal skills", "how_evidenced" => "Publications, presentations, client work" },
          { "name" => "Problem solving", "measures" => "Analytical thinking", "how_evidenced" => "Complex projects, innovations" },
          { "name" => "Industry knowledge", "measures" => "Domain expertise", "how_evidenced" => "Years in industry, specializations" },
          { "name" => "Delivery track record", "measures" => "Consistent delivery", "how_evidenced" => "Project completions, timelines" },
          { "name" => "Stakeholder management", "measures" => "Managing relationships", "how_evidenced" => "Client work, cross-functional projects" },
          { "name" => "Adaptability", "measures" => "Handling change", "how_evidenced" => "Career transitions, new environments" }
        ],
        "load_bearing" => ["Technical skills", "Delivery track record", "Industry knowledge"],
        "inconsistencies" => [],
        "silences" => []
      }
    end

    def weights_response
      {
        "weights" => {
          "Technical skills" => 20,
          "Leadership" => 15,
          "Communication" => 10,
          "Problem solving" => 15,
          "Industry knowledge" => 15,
          "Delivery track record" => 15,
          "Stakeholder management" => 5,
          "Adaptability" => 5
        },
        "total" => 100,
        "floor_attributes" => ["Technical skills", "Delivery track record", "Industry knowledge"],
        "scale" => {
          "0" => "nothing on the page",
          "1-3" => "claimed but not evidenced",
          "4-6" => "evidenced, but adjacent, junior, or dated",
          "7-8" => "evidenced, current, at the level the job needs",
          "9-10" => "evidenced, and above the level"
        }
      }
    end

    def human_gates_response
      {
        "human_gates" => [
          { "name" => "Client-facing", "question" => "Can this person hold a room with clients?" },
          { "name" => "Leadership presence", "question" => "Do they command respect and inspire confidence?" },
          { "name" => "Craft depth", "question" => "Is their technical craft genuine or performed?" }
        ],
        "note" => "These are kill factors, they are not scored, and no weighted score outranks them."
      }
    end

    def cv_response
      {
        "candidates" => [
          {
            "name" => "Candidate 1",
            "tenure_line" => [
              { "role" => "Senior Developer", "start" => "2020-01", "end" => "2024-01", "duration" => "4 years", "assumed" => false }
            ],
            "kill_gate" => [
              { "criterion" => "Degree requirement", "pass" => true, "cv_line" => "BSc Computer Science, 2015" }
            ],
            "scores" => {
              "Technical skills" => { "score" => 8, "mark" => "V", "evidenced" => true, "justification" => "Multiple complex projects" },
              "Leadership" => { "score" => 6, "mark" => "I", "evidenced" => false, "justification" => "Some team lead experience" },
              "Communication" => { "score" => 7, "mark" => "V", "evidenced" => true, "justification" => "Conference talks" },
              "Problem solving" => { "score" => 8, "mark" => "V", "evidenced" => true, "justification" => "Complex problem solving shown" },
              "Industry knowledge" => { "score" => 7, "mark" => "V", "evidenced" => true, "justification" => "10 years in industry" },
              "Delivery track record" => { "score" => 8, "mark" => "V", "evidenced" => true, "justification" => "Consistent delivery" },
              "Stakeholder management" => { "score" => 5, "mark" => "I", "evidenced" => false, "justification" => "Some client interaction" },
              "Adaptability" => { "score" => 6, "mark" => "I", "evidenced" => false, "justification" => "Career transitions" }
            },
            "kills" => ["Limited enterprise experience"],
            "strengths" => ["Strong technical depth", "Consistent delivery"],
            "questions" => [
              { "question" => "Tell me about a time you had to convince a skeptical stakeholder", "tests" => "Stakeholder management" }
            ],
            "recommendation" => "Strong candidate for the role"
          }
        ]
      }
    end

    def verification_response
      {
        "employers" => [
          {
            "name" => "Tech Corp",
            "legal_name" => "Tech Corporation Ltd",
            "trading_name" => "Tech Corp",
            "footprint" => 7,
            "turnover" => "$50M",
            "turnover_year" => "2023",
            "turnover_currency" => "USD",
            "turnover_source" => "audited",
            "headcount" => "200",
            "headcount_source" => "Company website",
            "headcount_date" => "2024",
            "function" => "Technology consulting",
            "claim_to_fame" => "Leading cloud migration specialist",
            "status" => "trading",
            "sources" => ["https://techcorp.example.com", "https://linkedin.com/company/techcorp"]
          }
        ],
        "claims" => [
          {
            "employer" => "Tech Corp",
            "candidate" => "Candidate 1",
            "cv_claim" => "Led cloud migration project",
            "classification" => "CONFIRMED",
            "search_description" => "Found press release confirming project leadership"
          }
        ],
        "score_movements" => []
      }
    end

    def report_response
      {
        "report_generated" => true,
        "page_count" => 7,
        "sections" => ["Summary", "Consolidated Evaluation", "Candidate 1 Assessment", "Candidate 1 Evidence", "Wrap-up"]
      }
    end
  end
end
