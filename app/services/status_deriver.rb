class StatusDeriver
  # Derives status from gate marks
  # 
  # CLEAR: every gate passed (all YES)
  # ENDED: one or more gates failed (any NO)
  # OPEN: no gate failed, but at least one is still unresolved (? or NOT_REACHED)
  
  class << self
    # Derive status for a candidate based on their gate marks
    def derive_status(candidate)
      marks = candidate.gate_marks.map(&:mark)
      
      return "open" if marks.empty?
      
      # A ? never yields CLEAR
      return "open" if marks.include?("?")
      
      # NOT_REACHED means unresolved
      return "open" if marks.include?("NOT_REACHED")
      
      # Any NO means ENDED
      return "ended" if marks.include?("NO")
      
      # All YES means CLEAR
      return "clear" if marks.all? { |m| m == "YES" }
      
      "open"
    end

    # Check if a candidate is CLEAR
    def clear?(candidate)
      derive_status(candidate) == "clear"
    end

    # Check if a candidate is ENDED
    def ended?(candidate)
      derive_status(candidate) == "ended"
    end

    # Check if a candidate is OPEN
    def open?(candidate)
      derive_status(candidate) == "open"
    end

    # Derive verdict text based on status
    def verdict_text(candidates)
      cleared = candidates.select { |c| clear?(c) }
      
      if cleared.any?
        names = cleared.map(&:name).join(", ")
        "The seat can be filled. #{names} cleared all gates."
      else
        "The seat is not filled. No candidate cleared all gates."
      end
    end

    # Validate that no ? was converted to YES
    def validate_marks!(submitted_marks, report_marks)
      submitted_marks.each do |key, mark|
        if mark == "?" && report_marks[key] == "YES"
          raise GateMarkError, "? cannot be converted to YES"
        end
      end
    end

    # Propagate NOT_REACHED after a NO
    def propagate_not_reached!(candidate, human_gates)
      gates = human_gates.sort_by(&:position)
      found_no = false
      
      gates.each do |gate|
        mark = candidate.gate_mark_for(gate)
        next unless mark
        
        if found_no
          # After a NO, remaining gates should be NOT_REACHED
          mark.update(mark: "NOT_REACHED") unless mark.not_reached?
        elsif mark.no?
          found_no = true
        end
      end
    end

    # Check that all cells are filled
    def all_cells_filled?(candidate, human_gates)
      human_gates.all? do |gate|
        !candidate.gate_mark_for(gate).nil?
      end
    end
  end

  class GateMarkError < StandardError; end
end
