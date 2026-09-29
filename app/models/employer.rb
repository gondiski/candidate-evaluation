class Employer < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :evaluation
  one_to_many :employer_sources
  one_to_many :claims

  FOOTPRINT_SCALE = {
    0 => "cannot be found, or exists only as a parked domain",
    (1..2) => "a website and nothing else — no press, no awards, no directory standing",
    (3..4) => "live site and social presence, one or two mentions, no independent validation",
    (5..6) => "live site and genuine independent press coverage, no filings",
    (7..8) => "public filings or strong institutional presence, no encyclopaedia entry",
    (9..10) => "encyclopaedia entry, public filings, continuous national press"
  }.freeze

  def validate
    super
    validates_presence [:evaluation_id, :name]
    validates_includes (0..10).to_a, :footprint, allow_nil: true
    validates_includes %w[trading distressed acquired defunct], :status, allow_nil: true
    validates_includes %w[audited stated aggregator not_found], :turnover_source, allow_nil: true
  end

  def researched?
    employer_sources.count > 0
  end

  def sources_with_urls
    employer_sources.map { |s| { url: s.url, retrieved_at: s.retrieved_at } }
  end

  def footprint_description
    return "not researched" unless researched?
    case footprint
    when 0 then FOOTPRINT_SCALE[0]
    when 1..2 then FOOTPRINT_SCALE[(1..2)]
    when 3..4 then FOOTPRINT_SCALE[(3..4)]
    when 5..6 then FOOTPRINT_SCALE[(5..6)]
    when 7..8 then FOOTPRINT_SCALE[(7..8)]
    when 9..10 then FOOTPRINT_SCALE[(9..10)]
    else "not rated"
    end
  end
end
