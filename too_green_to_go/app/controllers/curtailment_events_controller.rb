class CurtailmentEventsController < ApplicationController
  def index
    @events = CurtailmentEvent.order(detected_at: :desc).limit(50)
    @events = @events.active if params[:active] == "true"
  end

  def show
    @event = CurtailmentEvent.find(params[:id])
  end

  def trigger_alert
    @event = CurtailmentEvent.find(params[:id])
    @event.trigger_alert!
    redirect_to @event, notice: "Alert triggered with ElevenLabs audio."
  end
end
