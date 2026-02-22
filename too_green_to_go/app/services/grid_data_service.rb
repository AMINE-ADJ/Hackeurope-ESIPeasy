# app/services/grid_data_service.rb
#
# Susquehanna "Data to Insight" Pipeline
# Ingests real-time grid data from multiple sources:
# - Electricity Maps API (carbon intensity)
# - Public energy provider data (EDF, TotalEnergies, Enedis)
# - Weather APIs (for solar/wind forecasting)
#
# Transforms raw data into actionable GridState records
# that drive routing decisions and surplus detection.
#
class GridDataService
  ELECTRICITY_MAPS_URL = "https://api.electricitymap.org/v3"
  SUPPORTED_ZONES = %w[FR DE ES PT NL BE IT GB US-CAL-CISO US-NY-NYIS US-TEX-ERCO].freeze

  # Simulated realistic data for hackathon demo
  ZONE_PROFILES = {
    "FR" => { base_carbon: 60, renewable_base: 75, provider: "EDF", dominant: "nuclear" },
    "DE" => { base_carbon: 350, renewable_base: 45, provider: "EnBW", dominant: "wind" },
    "ES" => { base_carbon: 180, renewable_base: 55, provider: "Endesa", dominant: "solar" },
    "PT" => { base_carbon: 150, renewable_base: 60, provider: "EDP", dominant: "wind" },
    "NL" => { base_carbon: 400, renewable_base: 30, provider: "TenneT", dominant: "gas" },
    "BE" => { base_carbon: 160, renewable_base: 55, provider: "Elia", dominant: "nuclear" },
    "IT" => { base_carbon: 280, renewable_base: 40, provider: "Terna", dominant: "gas" },
    "GB" => { base_carbon: 200, renewable_base: 50, provider: "NationalGrid", dominant: "wind" },
    "US-CAL-CISO" => { base_carbon: 220, renewable_base: 60, provider: "CAISO", dominant: "solar" },
    "US-NY-NYIS" => { base_carbon: 300, renewable_base: 30, provider: "NYISO", dominant: "gas" },
    "US-TEX-ERCO" => { base_carbon: 380, renewable_base: 35, provider: "ERCOT", dominant: "wind" }
  }.freeze

  def self.ingest_all_zones!
    SUPPORTED_ZONES.map do |zone|
      new(zone).ingest!
    end
  end

  def initialize(zone)
    @zone = zone
    @profile = ZONE_PROFILES[zone] || ZONE_PROFILES["FR"]
  end

  def ingest!
    data = fetch_grid_data
    grid_state = create_grid_state(data)
    detect_surplus!(grid_state)
    detect_curtailment!(grid_state)
    update_compute_nodes!(grid_state)
    grid_state
  end

  private

  def fetch_grid_data
    # In production: hit Electricity Maps API
    # For hackathon: generate realistic data with time-based patterns
    hour = Time.current.hour
    minute = Time.current.min

    # Simulate solar/wind patterns
    solar_factor = solar_curve(hour)
    wind_factor = wind_curve(hour, minute)
    demand_factor = demand_curve(hour)

    base = @profile[:base_carbon]
    renewable_base = @profile[:renewable_base]

    # Carbon intensity inversely proportional to renewable generation
    renewable_boost = (solar_factor * 0.4 + wind_factor * 0.6) * 30
    renewable_pct = [renewable_base + renewable_boost + rand(-5..5), 100].min
    carbon_intensity = [base * (1.0 - renewable_boost / 100.0) + rand(-20..20), 10].max

    # Energy price correlated with demand and inverse of renewable supply
    base_price = 50.0
    price = base_price * demand_factor * (1.0 - renewable_boost / 200.0) + rand(-5..5)

    # Solar generation (MW)
    solar_mw = (solar_factor * 15000 * (renewable_base / 100.0)).round
    wind_mw = (wind_factor * 8000 * (renewable_base / 100.0)).round
    demand_mw = (45000 * demand_factor).round

    # Curtailment happens when generation >> demand
    total_generation = solar_mw + wind_mw + 20000 # add baseload
    curtailment = [total_generation - demand_mw, 0].max * 0.1

    {
      carbon_intensity: carbon_intensity.round(1),
      renewable_pct: renewable_pct.round(1),
      energy_price: price.round(2),
      solar_generation_mw: solar_mw,
      wind_generation_mw: wind_mw,
      demand_mw: demand_mw,
      curtailment_mw: curtailment.round(1),
      dominant_source: @profile[:dominant]
    }
  end

  def create_grid_state(data)
    # Forecast: simple trend extrapolation
    recent = GridState.for_zone(@zone).order(recorded_at: :desc).limit(6).pluck(:carbon_intensity).compact
    trend = recent.size >= 2 ? (recent.first - recent.last) / recent.size : 0

    GridState.create!(
      grid_zone: @zone,
      carbon_intensity: data[:carbon_intensity],
      renewable_pct: data[:renewable_pct],
      energy_price: data[:energy_price],
      solar_generation_mw: data[:solar_generation_mw],
      wind_generation_mw: data[:wind_generation_mw],
      demand_mw: data[:demand_mw],
      curtailment_mw: data[:curtailment_mw],
      dominant_source: data[:dominant_source],
      surplus_detected: data[:curtailment_mw] > 100 || data[:energy_price] < 20,
      forecast_carbon_1h: [data[:carbon_intensity] + trend * 2, 10].max.round(1),
      forecast_carbon_6h: [data[:carbon_intensity] + trend * 12, 10].max.round(1),
      recorded_at: Time.current,
      raw_data: data.to_json
    )
  end

  def detect_surplus!(grid_state)
    if grid_state.surplus_detected?
      Rails.logger.info("[GridData] SURPLUS detected in #{@zone}: curtailment=#{grid_state.curtailment_mw}MW, price=€#{grid_state.energy_price}/MWh")
      ActionCable.server.broadcast("grid_states", {
        event: "surplus_detected",
        zone: @zone,
        curtailment_mw: grid_state.curtailment_mw,
        price: grid_state.energy_price
      })
    end
  end

  def detect_curtailment!(grid_state)
    return unless grid_state.curtailment_mw.to_f > 200

    severity = case grid_state.curtailment_mw
               when 200..500 then "medium"
               when 500..1000 then "high"
               else "critical"
               end

    CurtailmentEvent.create!(
      grid_zone: @zone,
      curtailment_mw: grid_state.curtailment_mw,
      potential_savings_eur: (grid_state.curtailment_mw * 0.05).round(2),
      potential_carbon_savings_g: (grid_state.curtailment_mw * 200).round,
      severity: severity,
      alert_message: "#{severity.upcase}: #{grid_state.curtailment_mw.round}MW of renewable energy being curtailed in #{@zone}. Open GPU capacity now to capture green compute at #{grid_state.energy_price.round(2)} EUR/MWh!",
      detected_at: Time.current,
      expires_at: 2.hours.from_now
    )
  end

  def update_compute_nodes!(grid_state)
    ComputeNode.where(grid_zone: @zone).find_each do |node|
      node.update!(
        current_carbon_intensity: grid_state.carbon_intensity,
        current_energy_price: grid_state.energy_price,
        renewable_pct: grid_state.renewable_pct,
        green_compliant: grid_state.renewable_pct >= 50.0
      )
    end
  end

  # Time-based curves for realistic simulation
  def solar_curve(hour)
    # Peak at noon, zero at night
    return 0 if hour < 6 || hour > 20
    peak = 13
    spread = 4.0
    Math.exp(-((hour - peak) ** 2) / (2 * spread ** 2))
  end

  def wind_curve(hour, minute)
    # More random, slightly higher at night
    base = hour.between?(22, 6) ? 0.6 : 0.4
    base + Math.sin((hour * 60 + minute) * 0.01) * 0.3
  end

  def demand_curve(hour)
    # Morning and evening peaks
    case hour
    when 0..5 then 0.6
    when 6..8 then 0.8
    when 9..11 then 0.9
    when 12..14 then 1.0
    when 15..17 then 0.95
    when 18..21 then 1.1
    when 22..23 then 0.75
    else 0.7
    end
  end
end
