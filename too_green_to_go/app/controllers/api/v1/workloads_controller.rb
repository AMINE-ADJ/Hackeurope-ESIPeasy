module Api
  module V1
    class WorkloadsController < ApplicationController
      skip_before_action :verify_authenticity_token

      def index
        workloads = Workload.order(created_at: :desc).limit(50)
        render json: workloads.as_json(include: { compute_node: { only: [:name, :region, :grid_zone] } })
      end

      def show
        workload = Workload.find(params[:id])
        render json: workload.as_json(
          include: {
            compute_node: { only: [:name, :region, :grid_zone, :gpu_model] },
            routing_decisions: { only: [:decision_type, :reason, :score, :created_at] }
          }
        )
      end

      def create
        workload = Workload.new(workload_params)
        workload.status = "pending"

        # Auto-assign organization if not provided (frontend users)
        unless workload.organization_id
          workload.organization = Organization.where(org_type: "ai_consumer").first ||
                                  Organization.first
        end

        if workload.save
          render json: workload, status: :created
        else
          render json: { errors: workload.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def route
        workload = Workload.find(params[:id])
        result = BrokerAgentService.new(workload).route!

        workload.reload
        node = workload.compute_node

        # Calculate carbon metrics
        baseline_intensity = 400.0 # EU avg dirty grid gCO2/kWh
        actual_intensity = node ? (node.always_green? ? 0.0 : (node.current_carbon_intensity || 250.0)) : baseline_intensity
        gpu_kw = case node&.gpu_model
                 when /H100/ then 0.70; when /A100/ then 0.40
                 when /RTX 4090/ then 0.35; when /RTX 4080/ then 0.32
                 else 0.30
                 end
        hours = workload.estimated_duration_hours || 1.0
        pue = node&.pue_ratio || 1.2
        total_kwh = gpu_kw * hours * pue
        carbon_expected = (baseline_intensity * total_kwh).round(1)
        carbon_actual = (actual_intensity * total_kwh).round(1)
        carbon_saved = (carbon_expected - carbon_actual).round(1)

        render json: {
          success: result[:success],
          node: node&.as_json(only: [:id, :name, :region, :grid_zone, :gpu_model]),
          score: result[:score],
          tier: result[:tier],
          carbon: {
            expected_grams: carbon_expected,
            actual_grams: carbon_actual,
            saved_grams: carbon_saved,
            reduction_pct: carbon_expected > 0 ? ((carbon_saved / carbon_expected) * 100).round(1) : 0,
            baseline_intensity: baseline_intensity,
            actual_intensity: actual_intensity.round(1),
            renewable_pct: node&.renewable_pct&.round(1) || 0,
            energy_kwh: total_kwh.round(3)
          },
          pricing: node ? {
            hourly_rate: node.hourly_cost.round(2),
            estimated_total: (node.hourly_cost * hours).round(2),
            currency: "EUR"
          } : nil
        }
      end

      def complete
        workload = Workload.find(params[:id])
        workload.complete!
        render json: { success: true, workload_id: workload.id, status: workload.status }
      end

      private

      def workload_params
        params.permit(
          :organization_id, :name, :workload_type, :priority,
          :required_vram_mb, :max_carbon_intensity, :max_price_per_hour,
          :green_only, :estimated_duration_hours, :docker_image, :budget_max_eur
        )
      end
    end
  end
end
