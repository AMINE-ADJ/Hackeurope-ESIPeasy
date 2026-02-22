class WorkloadsController < ApplicationController
  before_action :set_workload, only: [:show, :route, :pause, :reroute, :complete]

  def index
    @workloads = Workload.order(created_at: :desc).includes(:compute_node, :organization)
    @workloads = @workloads.where(status: params[:status]) if params[:status].present?
  end

  def show
    @routing_decisions = @workload.routing_decisions.order(created_at: :desc)
    @transactions = @workload.transactions
  end

  def new
    @workload = Workload.new
    @organizations = Organization.active
  end

  def create
    @workload = Workload.new(workload_params)
    @workload.status = "pending"

    if @workload.save
      # Evaluate workload spec with Crusoe
      if @workload.spec.present?
        evaluation = CrusoeInferenceService.evaluate_workload_spec(@workload.spec.to_json)
        if evaluation[:success]
          @workload.update(
            estimated_duration_hours: evaluation[:estimated_duration_hours]
          )
        end
      end

      redirect_to @workload, notice: "Workload created. Ready to route."
    else
      @organizations = Organization.active
      render :new, status: :unprocessable_entity
    end
  end

  def route
    result = @workload.route!
    if result
      redirect_to @workload, notice: "Workload routed successfully."
    else
      redirect_to @workload, alert: "Failed to route workload."
    end
  end

  def pause
    @workload.pause!(reason: params[:reason] || "manual")
    redirect_to @workload, notice: "Workload paused."
  end

  def reroute
    result = BrokerAgentService.new(@workload).reroute!(reason: params[:reason] || "manual")
    if result[:success]
      redirect_to @workload, notice: "Workload rerouted to #{result[:node].name}."
    else
      redirect_to @workload, alert: "Reroute failed: #{result[:reason]}"
    end
  end

  def complete
    WorkloadCompletionJob.perform_later(@workload.id)
    redirect_to @workload, notice: "Workload marked for completion."
  end

  private

  def set_workload
    @workload = Workload.find(params[:id])
  end

  def workload_params
    params.require(:workload).permit(
      :organization_id, :name, :workload_type, :priority,
      :required_vram_mb, :max_carbon_intensity, :max_price_per_hour,
      :green_only, :estimated_duration_hours,
      :docker_image, :budget_max_eur, :green_tier,
      :checkpoint_enabled, :checkpoint_interval_minutes
    )
  end
end
