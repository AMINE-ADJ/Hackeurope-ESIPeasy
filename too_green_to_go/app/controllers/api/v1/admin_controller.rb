module Api
  module V1
    class AdminController < ApplicationController
      skip_before_action :verify_authenticity_token

      # GET /api/v1/admin
      def index
        render json: {
          waste_events: build_waste_events,
          cluster_overview: build_cluster_overview,
          recent_overrides: build_recent_overrides
        }
      end

      # POST /api/v1/admin/declare_waste_event
      def declare_waste_event
        zone = params[:grid_zone] || "US-TEX-ERCO"
        source = params[:source] || "Manual Declaration"
        capacity_mw = params[:capacity_mw]&.to_f || 1.0

        # Create a curtailment event representing the waste event
        event = CurtailmentEvent.create!(
          grid_zone: zone,
          curtailment_mw: capacity_mw * 1000, # Convert MW to kW conceptually; keep in MW
          potential_savings_eur: (capacity_mw * 50).round(2),
          potential_carbon_savings_g: (capacity_mw * 200_000).round,
          severity: capacity_mw > 2 ? "critical" : "high",
          alert_message: "WASTE EVENT: #{source} — #{capacity_mw}MW available at #{params[:location] || zone}. Flooding GPU cluster.",
          detected_at: Time.current,
          expires_at: (params[:duration_hours]&.to_f || 4).hours.from_now
        )

        # Also create a surplus grid state
        GridState.create!(
          grid_zone: zone,
          carbon_intensity: 0,
          renewable_pct: 100,
          energy_price: 5.0,
          curtailment_mw: capacity_mw * 100,
          surplus_detected: true,
          dominant_source: source.parameterize.underscore,
          recorded_at: Time.current
        )

        # Activate idle nodes in the zone
        activated = ComputeNode.where(grid_zone: zone, status: "idle").limit(50)
        activated_count = activated.count
        activated.update_all(
          status: "idle",
          renewable_pct: 100,
          green_compliant: true,
          current_carbon_intensity: 0,
          current_energy_price: 5.0
        )

        # Route any pending async workloads to surplus
        BrokerAgentService.route_async_on_surplus!(zone)

        render json: {
          success: true,
          event_id: event.id,
          gpus_activated: activated_count,
          message: "Waste event declared! #{activated_count} GPUs spinning up in #{zone}."
        }
      end

      # POST /api/v1/admin/override_routing
      def override_routing
        workload = Workload.find(params[:workload_id])
        node = ComputeNode.find(params[:node_id])

        workload.update!(compute_node: node, status: "running", started_at: Time.current)
        RoutingDecision.create!(
          workload: workload,
          compute_node: node,
          decision_type: "admin_override",
          reason: params[:reason] || "Manual admin override",
          carbon_intensity_at_decision: node.current_carbon_intensity,
          energy_price_at_decision: node.current_energy_price
        )

        render json: { success: true, workload_id: workload.id, node: node.name }
      end

      private

      def build_waste_events
        CurtailmentEvent.where("expires_at > ?", Time.current)
                        .order(detected_at: :desc)
                        .limit(10).map do |event|
          remaining = event.expires_at - Time.current
          hours = (remaining / 3600).floor
          minutes = ((remaining % 3600) / 60).floor

          {
            id: event.id,
            source: event.alert_message&.gsub(/^WASTE EVENT: /, "")&.split(" — ")&.first || "#{event.severity.capitalize} — #{event.grid_zone}",
            capacity: "#{(event.curtailment_mw || 0).round(1)} MW",
            timeLeft: "#{hours}h #{minutes}m",
            gpusActivated: event.workloads_routed_count || ComputeNode.where(grid_zone: event.grid_zone, status: "busy").count
          }
        end
      end

      def build_cluster_overview
        {
          gamer_nodes: ComputeNode.gamer_nodes.count,
          datacenter_nodes: ComputeNode.datacenter_nodes.count,
          recycler_nodes: ComputeNode.recycler_nodes.count,
          total_nodes: ComputeNode.count,
          busy_nodes: ComputeNode.where(status: "busy").count,
          idle_nodes: ComputeNode.where(status: "idle").count,
          mig_enabled: ComputeNode.mig_capable.count,
          green_compliant: ComputeNode.green.count
        }
      end

      def build_recent_overrides
        RoutingDecision.where(decision_type: "admin_override")
                       .order(created_at: :desc)
                       .limit(5)
                       .includes(:workload, :compute_node).map do |rd|
          {
            workload: rd.workload&.name,
            node: rd.compute_node&.name,
            reason: rd.reason,
            time: rd.created_at.iso8601
          }
        end
      end
    end
  end
end
