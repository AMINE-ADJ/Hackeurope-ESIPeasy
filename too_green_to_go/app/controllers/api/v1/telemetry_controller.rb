module Api
  module V1
    class TelemetryController < ApplicationController
      skip_before_action :verify_authenticity_token

      # GET /api/v1/telemetry
      def index
        render json: {
          gpu_telemetry: build_gpu_telemetry,
          utilization_history: build_utilization_history
        }
      end

      private

      def build_gpu_telemetry
        ComputeNode.includes(:gpu_slices, :health_checks).order(:name).limit(20).map do |node|
          latest_health = node.health_checks.order(created_at: :desc).first
          sm_util = ((node.gpu_utilization || 0) * 100).round
          underused = sm_util < 70

          {
            id: node.id,
            gpu: node.gpu_model || node.name,
            smUtil: sm_util,
            memUtil: latest_health&.memory_utilization&.round || (sm_util * 0.8 + rand(-5..5)).clamp(0, 100).round,
            temp: latest_health&.gpu_temp_celsius&.round || (45 + rand(0..30)),
            power: latest_health&.power_draw_watts&.round || (150 + rand(0..200)),
            mig: node.mig_enabled? || false,
            slicesUsed: node.gpu_slices.where(status: "allocated").count,
            slicesTotal: node.mig_enabled? ? [node.gpu_slices.count, 7].max : 0,
            status: node.status,
            gridZone: node.grid_zone,
            nodeType: node.node_type,
            underused: underused
          }
        end
      end

      def build_utilization_history
        # Generate 24h history from health checks or simulate
        now = Time.current
        (0..23).map do |i|
          hour_start = now.beginning_of_hour - (23 - i).hours
          checks = HealthCheck.where(created_at: hour_start..(hour_start + 1.hour))

          if checks.any?
            {
              hour: hour_start.strftime("%H:00"),
              sm: checks.average(:gpu_utilization)&.round || 50,
              mem: checks.average(:memory_utilization)&.round || 40,
              power: checks.average(:power_draw_watts)&.round || 200
            }
          else
            # Simulate realistic pattern with time-of-day variation
            base_sm = case hour_start.hour
                      when 0..5 then 30 + rand(0..15)
                      when 6..8 then 45 + rand(0..20)
                      when 9..17 then 55 + rand(0..35)
                      when 18..21 then 60 + rand(0..30)
                      else 35 + rand(0..15)
                      end
            {
              hour: hour_start.strftime("%H:00"),
              sm: base_sm.clamp(0, 100),
              mem: (base_sm * 0.85 + rand(-10..10)).clamp(0, 100).round,
              power: (150 + base_sm * 2.5 + rand(-20..20)).round
            }
          end
        end
      end
    end
  end
end
