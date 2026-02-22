# app/services/eleven_labs_service.rb
#
# ElevenLabs integration for real-time audio alerts
# Generates emotional, urgent audio alerts for datacenter operators
# when massive curtailment events are detected.
#
class ElevenLabsService
  BASE_URL = "https://api.elevenlabs.io/v1"
  API_KEY = ENV.fetch("ELEVENLABS_API_KEY", "demo-key")
  VOICE_ID = ENV.fetch("ELEVENLABS_VOICE_ID", "21m00Tcm4TlvDq8ikWAM") # Rachel voice

  class << self
    def generate_alert(curtailment_event)
      text = build_alert_text(curtailment_event)
      return mock_audio_url(curtailment_event) unless elevenlabs_live?

      response = HTTParty.post(
        "#{BASE_URL}/text-to-speech/#{VOICE_ID}",
        headers: {
          "xi-api-key" => API_KEY,
          "Content-Type" => "application/json",
          "Accept" => "audio/mpeg"
        },
        body: {
          text: text,
          model_id: "eleven_multilingual_v2",
          voice_settings: {
            stability: 0.3,        # More expressive/urgent
            similarity_boost: 0.8,
            style: 0.7,            # Emotional
            use_speaker_boost: true
          }
        }.to_json,
        timeout: 30
      )

      if response.success?
        # Store audio and return URL
        filename = "curtailment_#{curtailment_event.id}_#{Time.current.to_i}.mp3"
        filepath = Rails.root.join("public", "audio", filename)
        FileUtils.mkdir_p(filepath.dirname)
        File.binwrite(filepath, response.body)
        "/audio/#{filename}"
      else
        Rails.logger.error("[ElevenLabs] Failed: #{response.code}")
        mock_audio_url(curtailment_event)
      end
    end

    private

    def elevenlabs_live?
      ENV["ELEVENLABS_API_KEY"].present? && ENV["ELEVENLABS_API_KEY"] != "demo-key"
    end

    def build_alert_text(event)
      case event.severity
      when "critical"
        "CRITICAL ALERT! #{event.curtailment_mw.round} megawatts of clean renewable energy are being wasted RIGHT NOW in #{event.grid_zone}. " \
        "This is a massive opportunity. Open your GPU capacity immediately to capture green compute at just #{format_price(event)} euros per megawatt hour. " \
        "Estimated savings: #{event.potential_savings_eur.round} euros. Act now before this window closes!"
      when "high"
        "High priority alert for #{event.grid_zone}. #{event.curtailment_mw.round} megawatts of renewable energy curtailment detected. " \
        "GPU compute available at significantly reduced rates. Consider expanding your green capacity now."
      else
        "Grid update for #{event.grid_zone}: #{event.curtailment_mw.round} megawatts of surplus renewable energy available. " \
        "Green compute rates are favorable."
      end
    end

    def format_price(event)
      grid = GridState.latest_for_zone(event.grid_zone)
      grid&.energy_price&.round(2) || "competitive"
    end

    def mock_audio_url(event)
      # Return a placeholder for demo mode
      "/audio/demo_alert_#{event.severity}.mp3"
    end
  end
end
