class Scoring
  class << self
    # Compute weighted score for a candidate
    # Formula: sum(score x weight) / 100
    def weighted_score(candidate, weight_version)
      total = 0.0
      
      candidate.candidate_scores.each do |cs|
        effective_score = cs.evidenced ? cs.score : [cs.score, 3].min
        weight = weight_version.weight_for_driver(cs.driver_id)
        total += effective_score * weight
      end
      
      total / 100.0
    end

    # Compute floor score (lowest score among floor attributes)
    def floor_score(candidate, weight_version)
      floor_drivers = weight_version.floor_driver_ids_list
      min_score = Float::INFINITY
      
      candidate.candidate_scores.each do |cs|
        if floor_drivers.include?(cs.driver_id.to_s) || floor_drivers.include?(cs.driver_id)
          effective_score = cs.evidenced ? cs.score : [cs.score, 3].min
          min_score = [min_score, effective_score].min
        end
      end
      
      min_score == Float::INFINITY ? 0 : min_score
    end

    # Determine verdict based on floor rule
    # Floor <= 3 forces reject regardless of weighted score
    def verdict(floor)
      floor <= 3 ? "reject" : "pass"
    end

    # Apply evidence cap: score with evidenced=false capped at 3
    def effective_score(score, evidenced)
      evidenced ? score : [score, 3].min
    end

    # Validate weights sum to exactly 100
    def valid_weights?(weights_hash)
      weights_hash.values.sum == 100
    end

    # Validate score is integer 0-10
    def valid_score?(score)
      score.is_a?(Integer) && score >= 0 && score <= 10
    end

    # Validate floor count is 2-3
    def valid_floor_count?(floor_ids)
      floor_ids.length >= 2 && floor_ids.length <= 3
    end

    # Get score band description
    def score_band(score)
      case score
      when 0 then "nothing on the page"
      when 1..3 then "claimed but not evidenced"
      when 4..6 then "evidenced, but adjacent, junior, or dated"
      when 7..8 then "evidenced, current, at the level the job needs"
      when 9..10 then "evidenced, and above the level — would raise the bar of the team they join"
      else "invalid score"
      end
    end

    # Compute all scores for a candidate
    def compute_candidate_scores!(candidate)
      weight_version = candidate.evaluation.current_weight_version_record
      raise "No weight version settled" unless weight_version
      
      candidate.weighted_score = weighted_score(candidate, weight_version)
      candidate.floor_score = floor_score(candidate, weight_version)
      candidate.verdict = verdict(candidate.floor_score)
      candidate.save_changes
    end
  end
end
