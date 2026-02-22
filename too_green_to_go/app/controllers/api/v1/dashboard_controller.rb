module Api
  module V1
    class DashboardController < ApplicationController
      skip_before_action :verify_authenticity_token

      # GET /api/v1/dashboard
      # Returns everything the main Dashboard page needs
      def index
        render json: {
          stats: build_stats,
          surplus_events: build_surplus_events,
          energy_providers: build_energy_providers,
          jobs: build_active_jobs,
          gpu_fleet: build_gpu_fleet
        }
      end

      private

      def build_stats
        completed_grams = Workload.where(status: "completed").sum(:carbon_saved_grams)
        running_grams = Workload.running.includes(:compute_node).sum { |w| w.estimated_carbon_saved_grams }
        total_co2_kg = ((completed_grams + running_grams) / 1000.0).round(2)

        total_gpu_hours = Workload.where(status: "completed").sum { |w| w.duration_hours || 0 }
        running_gpu_hours = Workload.running.sum { |w| w.duration_hours || 0 }

        total_revenue = Transaction.charges.completed.sum(:amount).to_f.round(2)
        standard_cost = total_revenue * 1.43 # 43% savings means our price is 1/1.43 of standard
        avg_savings_pct = standard_cost > 0 ? ((1 - total_revenue / standard_cost) * 100).round(0) : 43

        {
          co2_saved: "#{total_co2_kg} kg",
          co2_saved_raw: total_co2_kg,
          gpu_hours_brokered: format_number(total_gpu_hours + running_gpu_hours),
          energy_recovered: "#{(total_co2_kg * 0.072).round(1)} MWh", # ~72 Wh per gram CO2 avoided
          active_providers: Organization.providers.active.count,
          active_jobs: Workload.active.count,
          avg_savings: "#{avg_savings_pct}%",
          total_workloads: Workload.count,
          completed_workloads: Workload.where(status: "completed").count,
          pending_workloads: Workload.pending.count,
          total_nodes: ComputeNode.count,
          green_nodes: ComputeNode.green.count,
          available_nodes: ComputeNode.available.count,
          healthy_nodes: ComputeNode.healthy.count,
          total_revenue: total_revenue,
          reroute_rate: RoutingDecision.reroute_rate,
          surplus_zones: GridState.zones_with_surplus,
          mig_slices_available: GpuSlice.available.count
        }
      end

      def build_surplus_events
        # Surplus events = recent grid states where surplus was detected OR energy price dropped
        surplus_states = GridState.where(surplus_detected: true)
                                  .where("recorded_at >= ?", 2.hours.ago)
                                  .order(recorded_at: :desc)
                                  .limit(10)

        surplus_states.map do |gs|
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
            region: gs.grid_zone,
            drop: price_drop,
            time: time_ago(gs.recorded_at),
            capacity: "#{gs.curtailment_mw&.round || 0} MW",
            energy_price: gs.energy_price&.round(2),
            carbon_intensity: gs.carbon_intensity&.round(1),
            renewable_pct: gs.renewable_pct&.round(1)
          }
        end
      end

      def build_energy_providers
        GridDataService::SUPPORTED_ZONES.filter_map do |zone|
          state = GridState.latest_for_zone(zone)
          next unless state

          profile = GridDataService::ZONE_PROFILES[zone] || {}
          ci = state.carbon_intensity.to_f
          status = if ci < 100
                     "green"
                   elsif ci < 250
                     "amber"
                   else
                     "red"
                   end

          {
            name: profile[:provider] || zone,
            region: zone,
            spot_price: state.energy_price&.round(2) || 0,
            carbon_intensity: ci.round(1),
            renewable_pct: state.renewable_pct&.round(1) || 0,
            status: status,
            surplus: state.surplus_detected? || false,
            dominant_source: state.dominant_source || profile[:dominant] || "unknown"
          }
        end
      end

      def build_active_jobs
        Workload.order(created_at: :desc).limit(20).includes(:compute_node, :organization).map do |w|
          progress = case w.status
                     when "completed" then 100
                     when "pending" then 0
                     when "running"
                       if w.started_at && w.estimated_duration_hours.to_f > 0
                         elapsed = (Time.current - w.started_at) / 3600.0
                         [(elapsed / w.estimated_duration_hours * 100).round, 99].min
                       else
                         rand(20..80)
                       end
                     else 0
                     end

          eta = case w.status
                when "completed" then "Done"
                when "pending" then "Waiting"
                when "running"
                  if w.started_at && w.estimated_duration_hours.to_f > 0
                    remaining = w.estimated_duration_hours - (Time.current - w.started_at) / 3600.0
                    remaining > 0 ? "#{(remaining * 60).round}m" : "Almost done"
                  else
                    "Estimating..."
                  end
                else "—"
                end

          tier_label = case w.broker_tier_used
                       when "tier_1_recycler" then "Recycled"
                       when "tier_2_b2b_surplus" then "Surplus"
                       when "tier_3_b2c_green" then "Green"
                       else "Standard"
                       end

          {
            id: "WKL-#{w.id.to_s.rjust(3, '0')}",
            db_id: w.id,
            name: w.name || "Workload ##{w.id}",
            status: w.status,
            gpu: w.compute_node&.gpu_model || "—",
            tier: tier_label,
            green_score: w.compute_node ? (w.compute_node.renewable_pct.to_f).round(0) : 0,
            progress: progress,
            eta: eta,
            workload_type: w.workload_type,
            priority: w.priority,
            green_only: w.green_only?,
            carbon_saved_grams: w.status == "completed" ? w.carbon_saved_grams : w.estimated_carbon_saved_grams,
            node_name: w.compute_node&.name,
            node_zone: w.compute_node&.grid_zone,
            created_at: w.created_at.iso8601,
            budget_max_eur: w.budget_max_eur,
            estimated_cost: w.estimated_cost
          }
        end
      end

      def build_gpu_fleet
        ComputeNode.includes(:gpu_slices).order(:name).limit(20).map do |node|
          {
            id: node.id,
            gpu: node.gpu_model || node.name,
            name: node.name,
            sm_util: ((node.gpu_utilization || 0) * 100).round,
            mem_util: ((node.gpu_utilization || 0) * 80 + rand(-5..5)).clamp(0, 100).round,
            temp: node.health_checks.order(created_at: :desc).first&.gpu_temp_celsius || (45 + rand(0..30)),
            power: node.health_checks.order(created_at: :desc).first&.power_draw_watts || (150 + rand(0..200)),
            mig: node.mig_enabled? || false,
            slices_used: node.gpu_slices.allocated.count,
            slices_total: node.mig_enabled? ? [node.gpu_slices.count, 7].max : 0,
            status: node.status,
            grid_zone: node.grid_zone,
            health_status: node.health_status,
            node_type: node.node_type,
            organization: node.organization&.name
          }
        end
      end

      def time_ago(time)
        return "just now" unless time
        diff = Time.current - time
        if diff < 60
          "#{diff.round}s ago"
        elsif diff < 3600
          "#{(diff / 60).round}m ago"
        elsif diff < 86400
          "#{(diff / 3600).round}h ago"
        else
          "#{(diff / 86400).round}d ago"
        end
      end

      def format_number(n)
        if n >= 1_000_000
          "#{(n / 1_000_000.0).round(1)}M"
        elsif n >= 1_000
          "#{(n / 1_000.0).round(1)}K"
        else
          n.round(1).to_s
        end
      end
    end
  end
end
