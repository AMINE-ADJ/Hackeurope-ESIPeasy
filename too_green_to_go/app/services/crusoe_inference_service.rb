# app/services/crusoe_inference_service.rb
#
# Integration with Crusoe Inference API
# Used for:
# 1. Running AI workloads on Crusoe's green GPU infrastructure
# 2. Internal embeddings for workload spec evaluation
# 3. Evaluating incoming B2B workload specs (complexity analysis)
#
class CrusoeInferenceService
  BASE_URL = ENV.fetch("CRUSOE_API_URL", "https://inference.crusoecloud.com/v1")
  API_KEY = ENV.fetch("CRUSOE_API_KEY", "demo-key")

  class << self
    # Submit a workload to Crusoe's inference API
    def submit_inference(workload)
      spec = workload.spec || {}

      payload = {
        model: spec["model"] || "meta-llama/Llama-3.3-70B-Instruct",
        messages: [
          { role: "system", content: "You are a helpful assistant." },
          { role: "user", content: spec["prompt"] || "Hello" }
        ],
        max_tokens: spec["max_tokens"] || 512,
        temperature: spec["temperature"] || 0.7,
        stream: false
      }

      response = make_request("/chat/completions", payload)

      if response[:success]
        workload.update!(crusoe_job_id: response[:id])
        Rails.logger.info("[Crusoe] Submitted job #{response[:id]} for workload #{workload.id}")
      end

      response
    end

    # Evaluate workload complexity using Crusoe embeddings
    def evaluate_workload_spec(spec_text)
      payload = {
        model: "text-embedding-3-small",
        input: spec_text
      }

      response = make_request("/embeddings", payload)

      if response[:success]
        embedding = response[:data]&.first&.dig("embedding") || []
        complexity = estimate_complexity(embedding)
        {
          success: true,
          complexity: complexity,
          recommended_gpu: recommend_gpu(complexity),
          estimated_duration_hours: estimate_duration(complexity)
        }
      else
        { success: false, error: response[:error] }
      end
    end

    # Check job status on Crusoe
    def check_job_status(crusoe_job_id)
      # In production, this would poll Crusoe's job status endpoint
      # For demo, simulate status tracking
      {
        job_id: crusoe_job_id,
        status: "running",
        progress: rand(20..95),
        gpu_utilization: rand(60..95) / 100.0,
        estimated_completion: Time.current + rand(10..60).minutes
      }
    end

    private

    def make_request(endpoint, payload)
      # For hackathon demo: simulate API responses
      # In production: actual HTTP call to Crusoe
      if ENV["CRUSOE_API_KEY"].present? && ENV["CRUSOE_API_KEY"] != "demo-key"
        begin
          response = HTTParty.post(
            "#{BASE_URL}#{endpoint}",
            headers: {
              "Authorization" => "Bearer #{API_KEY}",
              "Content-Type" => "application/json"
            },
            body: payload.to_json,
            timeout: 30
          )
          { success: response.success?, id: response.dig("id"), data: response.parsed_response }
        rescue => e
          { success: false, error: e.message }
        end
      else
        simulate_response(endpoint, payload)
      end
    end

    def simulate_response(endpoint, payload)
      case endpoint
      when "/chat/completions"
        {
          success: true,
          id: "crusoe-#{SecureRandom.hex(8)}",
          data: {
            "choices" => [{ "message" => { "content" => "Simulated inference response" } }],
            "usage" => { "prompt_tokens" => 50, "completion_tokens" => 100 }
          }
        }
      when "/embeddings"
        {
          success: true,
          data: [{ "embedding" => Array.new(1536) { rand(-1.0..1.0) } }]
        }
      else
        { success: false, error: "Unknown endpoint" }
      end
    end

    def estimate_complexity(embedding)
      return "medium" if embedding.empty?
      magnitude = Math.sqrt(embedding.sum { |x| x ** 2 })
      case magnitude
      when 0..15 then "low"
      when 15..30 then "medium"
      else "high"
      end
    end

    def recommend_gpu(complexity)
      case complexity
      when "low" then "RTX 4090"
      when "medium" then "A100"
      when "high" then "H100"
      else "A100"
      end
    end

    def estimate_duration(complexity)
      case complexity
      when "low" then 0.5
      when "medium" then 2.0
      when "high" then 8.0
      else 2.0
      end
    end
  end
end
