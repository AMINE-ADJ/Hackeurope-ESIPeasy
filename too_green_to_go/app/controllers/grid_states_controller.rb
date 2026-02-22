class GridStatesController < ApplicationController
  def index
    @grid_states = GridState.order(recorded_at: :desc).limit(100)
    @grid_states = @grid_states.for_zone(params[:zone]) if params[:zone].present?
  end

  def show
    @grid_state = GridState.find(params[:id])
  end

  def live_map
    @zones_data = GridDataService::SUPPORTED_ZONES.map do |zone|
      state = GridState.latest_for_zone(zone)
      {
        zone: zone,
        carbon_intensity: state&.carbon_intensity&.round(1) || 0,
        renewable_pct: state&.renewable_pct&.round(1) || 0,
        energy_price: state&.energy_price&.round(2) || 0,
        surplus: state&.surplus_detected || false,
        curtailment_mw: state&.curtailment_mw&.round || 0,
        dominant_source: state&.dominant_source || "unknown",
        forecast_1h: state&.forecast_carbon_1h&.round(1) || 0,
        trend: state&.carbon_trend || "stable"
      }
    end
  end

  def ingest
    GridDataService.ingest_all_zones!
    redirect_to grid_states_path, notice: "Grid data ingested for all zones."
  end
end
