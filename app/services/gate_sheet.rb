class GateSheet
  # Handles the gate sheet (page 2 of the report)
  # Manages marks: YES, NO, ?, NOT_REACHED
  
  VALID_MARKS = %w[YES NO ? NOT_REACHED].freeze
  
  class << self
    # Validate a mark is one of the four valid values
    def valid_mark?(mark)
      VALID_MARKS.include?(mark)
    end

    # Submit marks for a candidate
    # Enforces: no blanks, ? never becomes YES, NOT_REACHED propagation
    def submit_marks!(candidate, human_gates, marks_hash)
      DB.transaction do
        # Validate all marks are present
        human_gates.each do |gate|
          mark = marks_hash[gate.id.to_s] || marks_hash[gate.id]
          raise GateSheetError, "Blank cell for #{gate.name}" if mark.nil? || mark.empty?
          raise GateSheetError, "Invalid mark: #{mark}" unless valid_mark?(mark)
        end

        # Create or update marks
        human_gates.each do |gate|
          mark = marks_hash[gate.id.to_s] || marks_hash[gate.id]
          
          existing = candidate.gate_mark_for(gate)
          if existing
            # Validate ? never becomes YES
            if existing.mark == "?" && mark == "YES"
              raise GateSheetError, "? cannot be converted to YES for #{gate.name}"
            end
            existing.update(mark: mark)
          else
            GateMark.create(
              candidate_id: candidate.id,
              human_gate_id: gate.id,
              mark: mark
            )
          end
        end

        # Propagate NOT_REACHED after any NO
        propagate_not_reached!(candidate, human_gates)
      end
    end

    # Build empty gate sheet grid (for pre-interview report)
    def empty_grid(candidates, human_gates)
      grid = {}
      candidates.each do |candidate|
        grid[candidate.id] = {}
        human_gates.each do |gate|
          grid[candidate.id][gate.id] = "" # Empty - to be filled by hand
        end
      end
      grid
    end

    # Build completed gate sheet grid (for post-interview report)
    def completed_grid(candidates, human_gates)
      grid = {}
      candidates.each do |candidate|
        grid[candidate.id] = {}
        human_gates.each do |gate|
          mark = candidate.gate_mark_for(gate)
          grid[candidate.id][gate.id] = mark ? mark.mark : ""
        end
      end
      grid
    end

    # Get status for each candidate
    def candidate_statuses(candidates)
      candidates.map do |candidate|
        { candidate: candidate, status: StatusDeriver.derive_status(candidate) }
      end
    end

    # Generate the three rules text
    def three_rules
      <<~RULES
        One FAIL ends the candidacy, on any single line, regardless of the weighted score.
        A blank is not a pass — unassessed means unknown, and unknown does not clear a gate.
        Both halves must clear. The score measures what the paper supports; the boxes measure what the paper cannot show. Neither substitutes for the other.
      RULES
    end

    # Validate gate sheet is empty (for pre-interview report)
    def assert_empty!(candidates)
      candidates.each do |candidate|
        candidate.gate_marks.each do |mark|
          unless mark.mark.empty? || mark.mark.nil?
            raise GateSheetError, "Gate sheet must be empty for pre-interview report"
          end
        end
      end
    end

    # Validate all cells are filled (for post-interview report)
    def assert_complete!(candidates, human_gates)
      candidates.each do |candidate|
        human_gates.each do |gate|
          mark = candidate.gate_mark_for(gate)
          if mark.nil? || mark.mark.nil? || mark.mark.empty?
            raise GateSheetError, "Blank cell for #{candidate.name} - #{gate.name}"
          end
        end
      end
    end

    private

    def propagate_not_reached!(candidate, human_gates)
      gates = human_gates.sort_by(&:position)
      found_no = false
      
      gates.each do |gate|
        mark = candidate.gate_mark_for(gate)
        next unless mark
        
        if found_no
          mark.update(mark: "NOT_REACHED") unless mark.not_reached?
        elsif mark.no?
          found_no = true
        end
      end
    end
  end

  class GateSheetError < StandardError; end
end
