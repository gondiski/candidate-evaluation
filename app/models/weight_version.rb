class WeightVersion < Sequel::Model
  plugin :validation_helpers
  
  many_to_one :evaluation

  def validate
    super
    validates_presence [:evaluation_id, :version_number, :weights_json, :floor_driver_ids]
  end

  def before_create
    super
    self.created_at = Sequel::CURRENT_TIMESTAMP
  end

  def before_update
    # WeightVersions are immutable - prevent updates
    raise WeightVersionImmutableError, "Weight versions cannot be modified after creation"
  end

  def weights
    JSON.parse(weights_json)
  end

  def floor_driver_ids_list
    JSON.parse(floor_driver_ids)
  end

  def weight_for_driver(driver_id)
    weights[driver_id.to_s] || weights[driver_id] || 0
  end

  def floor_drivers
    Driver.where(id: floor_driver_ids_list).all
  end

  def verify_weights_sum_to_100!
    total = weights.values.sum
    unless total == 100
      raise WeightSumError, "Weights sum to #{total}, expected 100"
    end
    true
  end

  def verify_floor_count!
    count = floor_driver_ids_list.length
    unless count >= 2 && count <= 3
      raise FloorCountError, "Floor has #{count} attributes, expected 2-3"
    end
    true
  end
end

class WeightVersionImmutableError < StandardError; end
class WeightSumError < StandardError; end
class FloorCountError < StandardError; end
