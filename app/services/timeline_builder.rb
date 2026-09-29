require "date"

class TimelineBuilder
  # Builds career timelines from CV tenure data
  # Handles: mid-year assumption, concurrency, gaps, shared scale
  
  class << self
    # Parse tenure line from CV data
    # Returns array of roles with start, end, duration, assumed flag
    def parse_tenure_line(roles_json)
      roles = JSON.parse(roles_json) rescue []
      
      roles.map do |role|
        start_date = parse_date(role["start"], assume_mid_year: true)
        end_date = parse_date(role["end"], assume_mid_year: true)
        
        {
          title: role["title"] || role["role"],
          company: role["company"],
          start: start_date,
          end: end_date,
          duration_months: calculate_duration_months(start_date, end_date),
          assumed_start: role["start"]&.match?(/^\d{4}$/) || false,
          assumed_end: role["end"]&.match?(/^\d{4}$/) || false
        }
      end
    end

    # Detect concurrent roles
    def detect_concurrency(roles)
      return [] if roles.length < 2
      
      concurrent = []
      roles.combination(2).each do |a, b|
        if overlaps?(a[:start], a[:end], b[:start], b[:end])
          concurrent << [a[:title], b[:title]]
        end
      end
      concurrent
    end

    # Detect gaps between roles
    def detect_gaps(roles)
      return [] if roles.length < 2
      
      sorted = roles.sort_by { |r| r[:start] }
      gaps = []
      
      sorted.each_cons(2) do |a, b|
        if a[:end] && b[:start] && a[:end] < b[:start]
          gap_months = calculate_duration_months(a[:end], b[:start])
          if gap_months > 1
            gaps << {
              from: a[:title],
              to: b[:title],
              start: a[:end],
              end: b[:start],
              duration_months: gap_months
            }
          end
        end
      end
      gaps
    end

    # Calculate duration in months between two dates
    def calculate_duration_months(start_date, end_date)
      return nil unless start_date && end_date
      
      end_date = Date.today if end_date == "present"
      
      years = end_date.year - start_date.year
      months = end_date.month - start_date.month
      
      (years * 12) + months
    end

    # Format duration as human-readable string
    def format_duration(months)
      return "unknown" unless months
      
      years = months / 12
      remaining_months = months % 12
      
      if years > 0 && remaining_months > 0
        "#{years} year#{years > 1 ? 's' : ''}, #{remaining_months} month#{remaining_months > 1 ? 's' : ''}"
      elsif years > 0
        "#{years} year#{years > 1 ? 's' : ''}"
      else
        "#{remaining_months} month#{remaining_months > 1 ? 's' : ''}"
      end
    end

    # Build shared timeline for multiple candidates (comparative view)
    def build_shared_timeline(candidates)
      all_roles = []
      
      candidates.each do |candidate|
        roles = parse_tenure_line(candidate.tenure_line_json || "[]")
        roles.each do |role|
          all_roles << role.merge(candidate_id: candidate.id, candidate_name: candidate.name)
        end
      end
      
      # Find overall date range
      starts = all_roles.map { |r| r[:start] }.compact
      ends = all_roles.map { |r| r[:end] }.compact
      
      {
        roles: all_roles,
        earliest: starts.min,
        latest: ends.max,
        candidates: candidates.map { |c| { id: c.id, name: c.name } }
      }
    end

    # Build individual timeline for one candidate
    def build_individual_timeline(candidate)
      roles = parse_tenure_line(candidate.tenure_line_json || "[]")
      concurrency = detect_concurrency(roles)
      gaps = detect_gaps(roles)
      
      {
        roles: roles,
        concurrency: concurrency,
        gaps: gaps,
        total_duration_months: roles.sum { |r| r[:duration_months] || 0 }
      }
    end

    # Generate scale bar (length per year)
    def scale_bar(earliest, latest, width_px = 800)
      return nil unless earliest && latest
      
      total_years = (latest.year - earliest.year).to_f
      px_per_year = width_px / total_years
      
      {
        earliest: earliest,
        latest: latest,
        total_years: total_years,
        px_per_year: px_per_year,
        width_px: width_px
      }
    end

    private

    def parse_date(date_str, assume_mid_year: false)
      return nil if date_str.nil? || date_str.empty?
      return Date.today if date_str.downcase == "present"
      
      # Try full date first
      if date_str.match?(/^\d{4}-\d{2}-\d{2}$/)
        return Date.parse(date_str)
      end
      
      # Year and month
      if date_str.match?(/^\d{4}-\d{2}$/)
        return Date.parse("#{date_str}-01")
      end
      
      # Year only - assume mid-year if flagged
      if date_str.match?(/^\d{4}$/)
        if assume_mid_year
          return Date.new(date_str.to_i, 6, 15)
        else
          return Date.new(date_str.to_i, 1, 1)
        end
      end
      
      Date.parse(date_str) rescue nil
    end

    def overlaps?(a_start, a_end, b_start, b_end)
      return false unless a_start && a_end && b_start && b_end
      
      a_start <= b_end && b_start <= a_end
    end
  end
end
