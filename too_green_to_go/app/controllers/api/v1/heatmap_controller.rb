module Api
  module V1
    class HeatmapController < ApplicationController
      skip_before_action :verify_authenticity_token

      # GET /api/v1/heatmap
      def index
        render json: {
          regions: build_regions,
          energy_providers: build_energy_providers,
          surplus_events: build_surplus_events
        }
      end

      private

      ZONE_COORDS = {
        "FR" => { name: "France", lat: 46.6, lng: 2.2 },
        "DE" => { name: "Germany", lat: 51.2, lng: 10.4 },
        "ES" => { name: "Spain", lat: 40.5, lng: -3.7 },
        "PT" => { name: "Portugal", lat: 39.4, lng: -8.2 },
        "NL" => { name: "Netherlands", lat: 52.1, lng: 5.3 },
        "BE" => { name: "Belgium", lat: 50.5, lng: 4.4 },
        "IT" => { name: "Italy", lat: 42.5, lng: 12.5 },
        "GB" => { name: "United Kingdom", lat: 55.4, lng: -3.4 },
        "US-CAL-CISO" => { name: "California, US", lat: 36.8, lng: -119.4 },
        "US-NY-NYIS" => { name: "New York, US", lat: 42.2, lng: -74.0 },
        "US-TEX-ERCO" => { name: "Texas, US", lat: 31.0, lng: -99.0 }
      }.freeze

      def build_regions
        GridDataService::SUPPORTED_ZONES.filter_map do |zone|
          state = GridState.latest_for_zone(zone)
          coords = ZONE_COORDS[zone]
          next unless coords

          ci = state&.carbon_intensity.to_f
          status = if ci < 100 then "green"
                   elsif ci < 250 then "amber"
                   else "red"
                   end

          {
            id: zone.downcase.gsub(/[^a-z]/, "_"),
            name: coords[:name],
            lat: coords[:lat],
            lng: coords[:lng],
            price: state&.energy_price&.round(1) || 50.0,
            carbon: ci.round(0),
            renewable_pct: state&.renewable_pct&.round(1) || 0,
            status: status,
            surplus: state&.surplus_detected? || false,
            dominant_source: state&.dominant_source || "unknown",
            solar_mw: state&.solar_generation_mw || 0,
            wind_mw: state&.wind_generation_mw || 0,
            demand_mw: state&.demand_mw || 0,
            curtailment_mw: state&.curtailment_mw || 0,
            nodes_count: ComputeNode.where(grid_zone: zone).count
          }
        end
      end

      def build_energy_providers
        GridDataService::SUPPORTED_ZONES.filter_map do |zone|
          state = GridState.latest_for_zone(zone)
          next unless state

          profile = GridDataService::ZONE_PROFILES[zone] || {}
          ci = state.carbon_intensity.to_f
          status = if ci < 100 then "green"
                   elsif ci < 250 then "amber"
                   else "red"
                   end

          {
            name: profile[:provider] || zone,
            region: ZONE_COORDS[zone]&.dig(:name) || zone,
            spotPrice: state.energy_price&.round(2) || 0,
            carbonIntensity: ci.round(0),
            status: status,
            renewablePct: state.renewable_pct&.round(1) || 0,
            surplus: state.surplus_detected? || false
          }
        end
      end

      def build_surplus_events
        GridState.where(surplus_detected: true)
                 .where("recorded_at >= ?", 2.hours.ago)
                 .order(recorded_at: :desc)
                 .limit(10).map do |gs|
          profile = GridDataService::ZONE_PROFILES[gs.grid_zone] || {}
          prev = GridState.for_zone(gs.grid_zone)
                          .where("recorded_at < ?", gs.recorded_at)
                          .order(recorded_at: :desc).first

          price_drop = if prev && prev.energy_price.to_f > 0
                         pct = ((prev.energy_price - gs.energy_price) / prev.energy_price * 100).round(0)
                         pct > 0 ? "-#{pct}%" : "+#{pct.abs}%"
                       else
                         "-#{rand(15..45)}%"
                       end

          {
            id: gs.id,
            provider: profile[:provider] || gs.grid_zone,
            region: ZONE_COORDS[gs.grid_zone]&.dig(:name) || gs.grid_zone,
            drop: price_drop,
            time: time_ago(gs.recorded_at),
            capacity: "#{gs.curtailment_mw&.round || 0} MW"
          }
        end
      end

      def time_ago(time)
        return "just now" unless time
        diff = Time.current - time
        if diff < 60 then "#{diff.round}s ago"
        elsif diff < 3600 then "#{(diff / 60).round}m ago"
        elsif diff < 86400 then "#{(diff / 3600).round}h ago"
        else "#{(diff / 86400).round}d ago"
        end
      end
    end
  end
end
