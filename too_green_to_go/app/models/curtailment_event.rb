class CurtailmentEvent < ApplicationRecord
  validates :grid_zone, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :critical, -> { where(severity: "critical") }
  scope :unalerted, -> { where(alert_sent: false) }

  def active?
    expires_at.present? && expires_at > Time.current
  end

  after_create_commit -> { broadcast_prepend_to "curtailment_events", partial: "curtailment_events/event" }

  def self.active_for_zone(zone)
    active.where(grid_zone: zone).order(detected_at: :desc)
  end

  def trigger_alert!
    return if alert_sent?

    # Generate audio alert via ElevenLabs
    audio_url = ElevenLabsService.generate_alert(self)

    update!(
      alert_sent: true,
      elevenlabs_audio_url: audio_url
    )

    # Broadcast to operators watching this zone
    ActionCable.server.broadcast(
      "curtailment_#{grid_zone}",
      {
        event: "curtailment_alert",
        zone: grid_zone,
        severity: severity,
        curtailment_mw: curtailment_mw,
        message: alert_message,
        audio_url: audio_url
      }
    )
  end
end
