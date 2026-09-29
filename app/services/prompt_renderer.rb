require "erb"

class PromptRenderer
  # Renders prompt templates with evaluation context
  
  class << self
    # Render a prompt template with evaluation context
    def render(template_name, evaluation)
      template_path = "#{PROMPTS_DIR}/#{template_name}.md.erb"
      template = File.read(template_path)
      
      # Create binding with evaluation context
      context = PromptContext.new(evaluation)
      
      ERB.new(template).result(context.get_binding)
    end

    # Get the briefing prompt
    def briefing(evaluation)
      render("briefing", evaluation)
    end

    # Get Prompt A (Job Description)
    def prompt_a(evaluation)
      render("prompt_a", evaluation)
    end

    # Get Prompt B (Weights)
    def prompt_b(evaluation)
      render("prompt_b", evaluation)
    end

    # Get Prompt C (Human Gates)
    def prompt_c(evaluation)
      render("prompt_c", evaluation)
    end

    # Get Prompt D (CVs)
    def prompt_d(evaluation)
      render("prompt_d", evaluation)
    end

    # Get Prompt E (Verification)
    def prompt_e(evaluation)
      render("prompt_e", evaluation)
    end

    # Get Prompt F (Pre-report)
    def prompt_f(evaluation)
      render("prompt_f", evaluation)
    end

    # Get Prompt G (Diagnosis)
    def prompt_g(evaluation)
      render("prompt_g", evaluation)
    end

    # Get Prompt H (Final Report)
    def prompt_h(evaluation)
      render("prompt_h", evaluation)
    end
  end

  class PromptContext
    def initialize(evaluation)
      @evaluation = evaluation
    end

    def get_binding
      binding
    end
  end
end
