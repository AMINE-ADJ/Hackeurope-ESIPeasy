module Api
  module V1
    class OnboardingController < ApplicationController
      skip_before_action :verify_authenticity_token

      # POST /api/v1/onboarding/register
      def register
        org = Organization.find_or_create_by!(
          name: params[:name] || "New Provider #{SecureRandom.hex(3)}",
          org_type: map_role_to_org_type(params[:role])
        ) do |o|
          o.contact_email = params[:email]
          o.provider_type = params[:role]
          o.always_green = params[:role] == "recycler"
          o.waste_heat_source = params[:energy_source] if params[:role] == "recycler"
          o.waste_capacity_mw = params[:capacity_mw]&.to_f || 0
        end

        node = ComputeNode.create!(
          organization: org,
          name: "#{params[:gpu_model] || 'GPU'}-#{SecureRandom.hex(2)}",
          node_type: map_role_to_node_type(params[:role]),
          gpu_model: params[:gpu_model],
          gpu_vram_mb: (params[:vram_gb]&.to_i || 24) * 1024,
          region: params[:location] || params[:zip_code] || "Unknown",
          grid_zone: detect_grid_zone(params[:location] || params[:zip_code]),
          status: "idle",
          energy_source_type: params[:energy_source]&.parameterize&.underscore,
          cooling_type: params[:cooling_type] || "air",
          cooling_overhead_pct: params[:cooling_overhead]&.to_f || 15.0,
          mig_enabled: params[:gpu_model]&.match?(/A100|H100/),
          mig_max_slices: params[:gpu_model]&.match?(/H100/) ? 7 : (params[:gpu_model]&.match?(/A100/) ? 7 : 0)
        )

        render json: {
          success: true,
          organization_id: org.id,
          node_id: node.id,
          message: "Provider registered. Ready for benchmarking."
        }
      end

      # POST /api/v1/onboarding/benchmark
      def benchmark
        node = ComputeNode.find(params[:node_id])

        # Simulate benchmark results based on GPU model
        results = simulate_benchmark(node)

        node.update!(
          benchmark_completed: true,
          benchmark_score: results[:score],
          tflops_benchmark: results[:tflops],
          memory_bandwidth_gbps: results[:bandwidth],
          network_latency_ms: results[:latency],
          health_status: "healthy",
          last_health_check_at: Time.current
        )

        # Mark org as onboarded
        node.organization.update!(onboarding_completed: true, verified: true)

        render json: {
          success: true,
          results: {
            tflops: results[:tflops],
            vram: "#{node.gpu_vram_mb / 1024} GB",
            latency: "#{results[:latency]} ms",
            score: results[:score],
            bandwidth: "#{results[:bandwidth]} GB/s"
          }
        }
      end

      private

      def map_role_to_org_type(role)
        case role
        when "gamer" then "gamer"
        when "datacenter" then "datacenter"
        when "recycler" then "energy_recycler"
        else "datacenter"
        end
      end

      def map_role_to_node_type(role)
        case role
        when "gamer" then "gamer"
        when "datacenter" then "datacenter"
        when "recycler" then "energy_recycler"
        else "datacenter"
        end
      end

      def detect_grid_zone(location)
        return "FR" unless location
        loc = location.to_s.downcase
        if loc.match?(/france|paris|lyon|marseille|fr|750/)
          "FR"
        elsif loc.match?(/germany|berlin|frankfurt|de/)
          "DE"
        elsif loc.match?(/spain|madrid|barcelona|es/)
          "ES"
        elsif loc.match?(/texas|tx|permian|houston/)
          "US-TEX-ERCO"
        elsif loc.match?(/california|ca|los angeles|sf/)
          "US-CAL-CISO"
        elsif loc.match?(/new york|ny|nyc/)
          "US-NY-NYIS"
        elsif loc.match?(/uk|london|gb/)
          "GB"
        elsif loc.match?(/italy|rome|milan|it/)
          "IT"
        elsif loc.match?(/netherlands|amsterdam|nl/)
          "NL"
        elsif loc.match?(/belgium|brussels|be/)
          "BE"
        elsif loc.match?(/portugal|lisbon|pt/)
          "PT"
        else
          "FR"
        end
      end

      def simulate_benchmark(node)
        base = case node.gpu_model
               when /H100/ then { tflops: 989.4, bandwidth: 3350, latency: 8, score: 98 }
               when /A100/ then { tflops: 312.0, bandwidth: 2039, latency: 10, score: 88 }
               when /RTX 4090/ then { tflops: 82.6, bandwidth: 1008, latency: 12, score: 82 }
               when /RTX 4080/ then { tflops: 48.7, bandwidth: 716, latency: 14, score: 75 }
               when /RTX 3090/ then { tflops: 35.6, bandwidth: 936, latency: 15, score: 72 }
               when /RTX 3080/ then { tflops: 29.8, bandwidth: 760, latency: 16, score: 68 }
               when /RTX 3070/ then { tflops: 20.3, bandwidth: 448, latency: 18, score: 62 }
               else { tflops: 25.0, bandwidth: 500, latency: 15, score: 65 }
               end

        # Add slight randomness to seem realistic
        {
          tflops: (base[:tflops] * (0.95 + rand * 0.1)).round(1),
          bandwidth: (base[:bandwidth] * (0.95 + rand * 0.1)).round(0),
          latency: (base[:latency] + rand(-2..2)).clamp(5, 30),
          score: (base[:score] + rand(-3..3)).clamp(50, 100)
        }
      end
    end
  end
end
