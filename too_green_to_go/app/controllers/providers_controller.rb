# Provider Onboarding Controller
# Handles registration for all 3 provider roles: Gamer, Data Center, Energy Recycler
# Includes hardware registration forms and automated benchmarking
class ProvidersController < ApplicationController
  before_action :set_organization, only: [:show, :edit, :update, :benchmark, :onboard_complete]

  def index
    @providers = Organization.providers.includes(:compute_nodes).order(created_at: :desc)
    @providers = @providers.where(org_type: params[:type]) if params[:type].present?
  end

  def show
    @nodes = @organization.compute_nodes.includes(:gpu_slices, :benchmarks, :health_checks)
    @compliance = @organization.compute_nodes.map { |n| GreenComplianceEngine.compliant?(n) }
    @revenue = @organization.revenue_this_month
    @carbon_saved = @organization.total_carbon_saved
  end

  def new
    @organization = Organization.new
  end

  def create
    @organization = Organization.new(provider_params)
    @organization.provider_type = @organization.org_type
    @organization.always_green = true if @organization.energy_recycler?

    if @organization.save
      redirect_to provider_onboard_path(@organization), notice: "Provider registered! Complete hardware onboarding."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @organization.update(provider_params)
      redirect_to provider_path(@organization), notice: "Provider updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Hardware registration + onboarding flow
  def onboard
    @organization = Organization.find(params[:id])
    @node = ComputeNode.new
  end

  def register_hardware
    @organization = Organization.find(params[:id])
    @node = @organization.compute_nodes.new(hardware_params)
    @node.node_type = @organization.org_type == "energy_recycler" ? "energy_recycler" : @organization.org_type

    if @node.save
      # Auto-run benchmark
      benchmark = @node.run_benchmark!("full_suite")

      # Create MIG slices if applicable
      if @node.mig_enabled? && @node.gpu_utilization.to_f < 0.7
        GpuSlice.create_slices_for_node!(@node)
      end

      redirect_to provider_path(@organization), notice: "Hardware registered and benchmarked (score: #{benchmark.score.round(1)})."
    else
      render :onboard, status: :unprocessable_entity
    end
  end

  # Trigger benchmark for existing node
  def benchmark
    node = @organization.compute_nodes.find(params[:node_id])
    benchmark = node.run_benchmark!("full_suite")
    redirect_to provider_path(@organization), notice: "Benchmark completed: #{benchmark.score.round(1)}"
  end

  def onboard_complete
    @organization.update!(onboarding_completed: true, verified: true)
    redirect_to provider_path(@organization), notice: "Onboarding complete! Provider is now verified and active."
  end

  private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  def provider_params
    params.require(:organization).permit(
      :name, :org_type, :contact_email, :tier,
      :waste_heat_source, :waste_capacity_mw
    )
  end

  def hardware_params
    params.require(:compute_node).permit(
      :name, :gpu_model, :gpu_vram_mb, :region, :grid_zone,
      :energy_provider, :latitude, :longitude, :solana_wallet_address,
      :cooling_type, :cooling_overhead_pct, :energy_source_type,
      :pue_ratio, :mig_enabled, :mig_max_slices
    )
  end
end
