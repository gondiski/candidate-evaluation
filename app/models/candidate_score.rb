class CandidateScore < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :candidate
  many_to_one :driver

  SCORE_BANDS = {
    0 => "nothing on the page",
    (1..3) => "claimed but not evidenced",
    (4..6) => "evidenced, but adjacent, junior, or dated",
    (7..8) => "evidenced, current, at the level the job needs",
    (9..10) => "evidenced, and above the level — would raise the bar of the team they join"
  }.freeze

  def validate
    super
    validates_presence [:candidate_id, :driver_id, :score, :mark]
    validates_includes (0..10).to_a, :score
    validates_includes %w[V I], :mark
  end

  def effective_score
    evidenced ? score : [score, 3].min
  end

  def score_band
    case score
    when 0 then "nothing on the page"
    when 1..3 then "claimed but not evidenced"
    when 4..6 then "evidenced, but adjacent, junior, or dated"
    when 7..8 then "evidenced, current, at the level the job needs"
    when 9..10 then "evidenced, and above the level"
    end
  end
end
