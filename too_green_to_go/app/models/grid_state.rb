class GridState < ApplicationRecord
  validates :grid_zone, presence: true
  validates :recorded_at, presence: true

  scope :recent, -> { where("recorded_at >= ?", 1.hour.ago) }
  scope :for_zone, ->(zone) { where(grid_zone: zone) }
  scope :surplus, -> { where(surplus_detected: true) }

  after_create_commit -> { broadcast_append_to "grid_states", partial: "grid_states/grid_state" }

  def self.latest_for_zone(zone)
    for_zone(zone).order(recorded_at: :desc).first
  end

  def self.zones_with_surplus
    recent.surplus.distinct.pluck(:grid_zone)
  end

  def green?
    renewable_pct.to_f >= 50.0
  end

  def surplus?
    surplus_detected? || curtailment_mw.to_f > 50.0
  end

  def carbon_trend(lookback: 6)
    previous = self.class.for_zone(grid_zone)
                         .where("recorded_at < ?", recorded_at)
                         .order(recorded_at: :desc)
                         .limit(lookback)
                         .pluck(:carbon_intensity)
    return "stable" if previous.empty?

    avg = previous.sum / previous.size
    diff = carbon_intensity - avg
    if diff > 20
      "rising"
    elsif diff < -20
      "falling"
    else
      "stable"
    end
  end
end
