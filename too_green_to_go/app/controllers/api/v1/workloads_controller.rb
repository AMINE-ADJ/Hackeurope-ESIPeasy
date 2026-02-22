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

        if workload.save
          render json: workload, status: :created
        else
          render json: { errors: workload.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def route
        workload = Workload.find(params[:id])
        result = BrokerAgentService.new(workload).route!
        render json: {
          success: result[:success],
          node: result[:node]&.as_json(only: [:id, :name, :region, :grid_zone]),
          score: result[:score]
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
          :green_only, :estimated_duration_hours
        )
      end
    end
  end
end
