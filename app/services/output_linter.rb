class OutputLinter
  # Checks every LLM response and flags issues
  # Does NOT silently fix - stores flags and shows warnings
  
  MAX_SENTENCE_LENGTH = 28
  
  PRAISE_WORDS = %w[
    excellent outstanding exceptional impressive remarkable
    brilliant fantastic wonderful amazing extraordinary
    superb magnificent stellar phenomenal terrific
  ].freeze
  
  FLATTERY_WORDS = %w[
    compliment praise congratulate admiration
    applaud commend laud extol
  ].freeze
  
  class << self
    # Lint an LLM response and return flags
    def lint(content, evaluation = nil)
      flags = []
      
      # Convert content to string for analysis
      text = content.is_a?(Hash) ? content.to_json : content.to_s
      
      # Check sentence length
      long_sentences = check_sentence_length(text)
      if long_sentences.any?
        flags << {
          type: "sentence_length",
          message: "#{long_sentences.length} sentence(s) exceed #{MAX_SENTENCE_LENGTH} words",
          details: long_sentences
        }
      end
      
      # Check for praise/flattery
      praise_found = check_praise_flattery(text)
      if praise_found.any?
        flags << {
          type: "praise_flattery",
          message: "Contains praise or flattery language",
          details: praise_found
        }
      end
      
      # Check for "fabricated" about unfound claims
      fabricated = check_fabricated_usage(text)
      if fabricated.any?
        flags << {
          type: "fabricated_usage",
          message: "Uses 'fabricated' for unfound claims",
          details: fabricated
        }
      end
      
      # Check for "verified" without URL
      verified = check_verified_without_url(text)
      if verified.any?
        flags << {
          type: "verified_no_url",
          message: "Claims 'verified' without providing URL",
          details: verified
        }
      end
      
      # Check for missing V/I marks
      missing_marks = check_missing_marks(text)
      if missing_marks.any?
        flags << {
          type: "missing_marks",
          message: "Scores missing V/I marks",
          details: missing_marks
        }
      end
      
      flags
    end

    # Check if response has any flags
    def flagged?(content, evaluation = nil)
      lint(content, evaluation).any?
    end

    # Get flag summary
    def flag_summary(content, evaluation = nil)
      flags = lint(content, evaluation)
      flags.map { |f| f[:message] }.join("; ")
    end

    private

    def check_sentence_length(text)
      sentences = text.split(/[.!?]+/)
      long_sentences = []
      
      sentences.each do |sentence|
        words = sentence.split(/\s+/).reject(&:empty?)
        if words.length > MAX_SENTENCE_LENGTH
          long_sentences << {
            sentence: sentence.strip,
            word_count: words.length
          }
        end
      end
      
      long_sentences
    end

    def check_praise_flattery(text)
      found = []
      lower_text = text.downcase
      
      PRAISE_WORDS.each do |word|
        if lower_text.include?(word)
          found << { word: word, context: extract_context(text, word) }
        end
      end
      
      FLATTERY_WORDS.each do |word|
        if lower_text.include?(word)
          found << { word: word, context: extract_context(text, word) }
        end
      end
      
      found
    end

    def check_fabricated_usage(text)
      found = []
      lower_text = text.downcase
      
      # Check for "fabricated" near "not found" or similar
      if lower_text.include?("fabricated")
        # Check context - is it about unfound claims?
        sentences = text.split(/[.!?]+/)
        sentences.each do |sentence|
          if sentence.downcase.include?("fabricated") && 
             (sentence.downcase.include?("not found") || 
              sentence.downcase.include?("cannot find") ||
              sentence.downcase.include?("could not find") ||
              sentence.downcase.include?("unsubstantiated"))
            found << { sentence: sentence.strip }
          end
        end
      end
      
      found
    end

    def check_verified_without_url(text)
      found = []
      lower_text = text.downcase
      
      # Check for "verified" without URL nearby
      sentences = text.split(/[.!?]+/)
      sentences.each do |sentence|
        if sentence.downcase.include?("verified")
          # Check if URL is present in same sentence or nearby
          unless sentence.match?(/https?:\/\//) || sentence.match?(/www\./)
            found << { sentence: sentence.strip }
          end
        end
      end
      
      found
    end

    def check_missing_marks(text)
      found = []
      
      # Look for score patterns without V/I marks
      # Pattern: number followed by score context but no V or I
      score_patterns = [
        /score[:\s]+(\d+)/i,
        /(\d+)\/10/,
        /rated[:\s]+(\d+)/i
      ]
      
      score_patterns.each do |pattern|
        text.scan(pattern) do |match|
          # Check if V or I is nearby
          pos = text.index(match[0])
          context = text[[pos - 50, 0].max..[pos + 50, text.length].min]
          unless context.match?(/\b[VI]\b/)
            found << { score: match[0], context: context }
          end
        end
      end
      
      found
    end

    def extract_context(text, word, context_length = 50)
      pos = text.downcase.index(word)
      return "" unless pos
      
      start_pos = [pos - context_length, 0].max
      end_pos = [pos + word.length + context_length, text.length].min
      
      context = text[start_pos...end_pos]
      context = "..." if start_pos > 0
      context += "..." if end_pos < text.length
      
      context
    end
  end
end
