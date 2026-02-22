module Api
  module V1
    class MarketplaceController < ApplicationController
      skip_before_action :verify_authenticity_token

      # GET /api/v1/marketplace
      # Returns GPU listings for the marketplace page
      def index
        nodes = ComputeNode.includes(:organization, :gpu_slices).order(:gpu_model)

        # Optional filters
        nodes = nodes.where(node_type: params[:provider_type]) if params[:provider_type].present?
        nodes = nodes.where("gpu_model LIKE ?", "%#{params[:search]}%") if params[:search].present?

        listings = nodes.map do |node|
          green_score = calculate_green_score(node)
          provider_label = case node.node_type
                           when "gamer" then "Gamer"
                           when "datacenter" then "Data Center"
                           when "energy_recycler" then "Recycler"
                           else "Other"
                           end

          pricing = DynamicPricingService.price_for(node)

          {
            id: node.id,
            gpu: node.gpu_model || node.name,
            vram: "#{(node.gpu_vram_mb || 0) / 1024}GB",
            vram_mb: node.gpu_vram_mb,
            provider: provider_label,
            provider_name: node.organization&.name,
            green_score: green_score,
            price: pricing[:final_rate].round(2),
            price_details: {
              base_rate: pricing[:base_rate],
              tier: pricing[:tier],
              surplus_discount_pct: pricing[:surplus_discount_pct],
              green_premium_pct: pricing[:green_premium_pct],
              demand_multiplier: pricing[:demand_multiplier]
            },
            location: "#{node.region || node.grid_zone}",
            grid_zone: node.grid_zone,
            status: node.status == "idle" ? "available" : node.status == "partial" ? "available" : node.status == "busy" ? "busy" : "offline",
            node_type: node.node_type,
            mig_enabled: node.mig_enabled?,
            available_slices: node.gpu_slices.available.count,
            carbon_intensity: node.current_carbon_intensity&.round(1) || 0,
            renewable_pct: node.renewable_pct&.round(1) || 0,
            health_status: node.health_status,
            benchmark_score: node.benchmark_score
          }
        end

        # Sort: green score desc, then price asc
        listings.sort_by! { |l| [-l[:green_score], l[:price]] }

        render json: {
          listings: listings,
          broker_priority: [
            { rank: 1, label: "Energy Recycler", description: "100% recycled/waste energy sources" },
            { rank: 2, label: "Surplus DC", description: "Data centers during energy surplus windows" },
            { rank: 3, label: "Green Gamer", description: "Community GPUs on green grid" }
          ],
          filters: {
            provider_types: ["Gamer", "Data Center", "Recycler"],
            gpu_models: ComputeNode.distinct.pluck(:gpu_model).compact,
            grid_zones: ComputeNode.distinct.pluck(:grid_zone).compact
          }
        }
      end

      # POST /api/v1/marketplace/:id/deploy
      # Deploy a workload onto a specific node
      def deploy
        node = ComputeNode.find(params[:id])
        org = Organization.where(org_type: "ai_consumer").first || Organization.first

        workload = Workload.create!(
          organization: org,
          compute_node: node,
          name: params[:name] || "Deploy on #{node.gpu_model}",
          workload_type: params[:workload_type] || "inference",
          priority: params[:priority] || "normal",
          required_vram_mb: params[:vram_mb]&.to_i || node.gpu_vram_mb,
          green_only: params[:green_only] == true,
          estimated_duration_hours: params[:duration_hours]&.to_f || 1.0,
          docker_image: params[:docker_image] || "ghcr.io/default/workload:latest",
          budget_max_eur: params[:budget]&.to_f,
          status: "pending"
        )

        result = BrokerAgentService.new(workload).route!

        render json: {
          success: result[:success],
          workload: {
            id: workload.id,
            name: workload.name,
            status: workload.status,
            node: result[:node]&.name,
            tier: result[:tier]
          }
        }
      end

      private

      def calculate_green_score(node)
        return 100 if node.always_green?
        score = 0
        score += (node.renewable_pct || 0) * 0.5
        score += 25 if node.green_compliant?
        score += 15 if node.surplus_energy?
        score += 10 if node.health_status == "healthy"
        score.clamp(0, 100).round
      end
    end
  end
end
