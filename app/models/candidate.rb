require "json"

class Candidate < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :evaluation
  one_to_many :candidate_scores
  one_to_many :gate_marks
  one_to_many :claims
  one_to_many :score_movements

  def validate
    super
    validates_presence [:evaluation_id, :name, :label]
  end

  def before_create
    super
    self.created_at = Sequel::CURRENT_TIMESTAMP
    self.updated_at = Sequel::CURRENT_TIMESTAMP
  end

  def before_update
    super
    self.updated_at = Sequel::CURRENT_TIMESTAMP
  end

  def tenure_roles
    return [] unless tenure_line_json
    JSON.parse(tenure_line_json)
  end

  def tenure_roles=(roles)
    self.tenure_line_json = roles.to_json
  end

  def kills_list
    return [] unless kills
    JSON.parse(kills)
  end

  def kills_list=(list)
    self.kills = list.to_json
  end

  def strengths_list
    return [] unless strengths
    JSON.parse(strengths)
  end

  def strengths_list=(list)
    self.strengths = list.to_json
  end

  def questions
    return [] unless three_questions_json
    JSON.parse(three_questions_json)
  end

  def questions=(qs)
    self.three_questions_json = qs.to_json
  end

  def gate_mark_for(human_gate)
    GateMark.where(candidate_id: id, human_gate_id: human_gate.id).first
  end

  def score_for(driver)
    candidate_scores.where(driver_id: driver.id).first
  end

  def compute_scores!
    weight_version = evaluation.current_weight_version_record
    raise "No weight version settled" unless weight_version

    weighted_total = 0.0
    floor_score = Float::INFINITY
    floor_drivers = weight_version.floor_driver_ids_list

    candidate_scores.each do |cs|
      # Apply evidence cap: if not evidenced, cap at 3
      effective_score = cs.evidenced ? cs.score : [cs.score, 3].min
      
      weight = weight_version.weight_for_driver(cs.driver_id)
      weighted_total += effective_score * weight

      # Track floor score
      if floor_drivers.include?(cs.driver_id.to_s) || floor_drivers.include?(cs.driver_id)
        floor_score = [floor_score, effective_score].min
      end
    end

    self.weighted_score = weighted_total / 100.0
    self.floor_score = floor_score == Float::INFINITY ? 0 : floor_score

    # Determine verdict based on floor rule
    if floor_score <= 3
      self.verdict = "reject"
    else
      self.verdict = "pass"
    end

    save_changes
  end

  def status
    return "ended" if verdict == "reject" || verdict == "ended"
    
    marks = gate_marks.map(&:mark)
    return "open" if marks.empty?
    
    if marks.include?("NO")
      "ended"
    elsif marks.include?("?") || marks.include?("NOT_REACHED")
      "open"
    elsif marks.all? { |m| m == "YES" }
      "clear"
    else
      "open"
    end
  end

  def clear?
    status == "clear"
  end

  def ended?
    status == "ended"
  end

  def open?
    status == "open"
  end

  def cv_text
    return nil unless cv_text_encrypted
    decrypt(cv_text_encrypted)
  end

  def cv_text=(text)
    self.cv_text_encrypted = encrypt(text)
  end

  private

  def encrypt(text)
    return nil if text.nil?
    cipher = OpenSSL::Cipher.new('aes-256-cbc')
    cipher.encrypt
    cipher.key = Digest::SHA256.digest(ENV.fetch('ENCRYPTION_KEY', 'default_key_change_me'))
    iv = cipher.random_iv
    encrypted = cipher.update(text) + cipher.final
    Base64.strict_encode64(iv + encrypted)
  end

  def decrypt(encrypted_text)
    return nil if encrypted_text.nil?
    decoded = Base64.strict_decode64(encrypted_text)
    cipher = OpenSSL::Cipher.new('aes-256-cbc')
    cipher.decrypt
    cipher.key = Digest::SHA256.digest(ENV.fetch('ENCRYPTION_KEY', 'default_key_change_me'))
    iv = decoded[0, 16]
    cipher.iv = iv
    cipher.update(decoded[16..]) + cipher.final
  end
end
