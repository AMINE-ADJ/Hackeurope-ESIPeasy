class ComputeNodesController < ApplicationController
  def index
    @nodes = ComputeNode.order(created_at: :desc).includes(:organization)
    @nodes = @nodes.where(status: params[:status]) if params[:status].present?
    @nodes = @nodes.where(grid_zone: params[:zone]) if params[:zone].present?
    @nodes = @nodes.green if params[:green] == "true"
  end

  def show
    @node = ComputeNode.find(params[:id])
    @workloads = @node.workloads.order(created_at: :desc).limit(10)
    @grid_history = GridState.for_zone(@node.grid_zone).order(recorded_at: :desc).limit(24)
  end

  def new
    @node = ComputeNode.new
    @organizations = Organization.active
  end

  def create
    @node = ComputeNode.new(node_params)
    if @node.save
      redirect_to @node, notice: "Compute node registered."
    else
      @organizations = Organization.active
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @node = ComputeNode.find(params[:id])
    @organizations = Organization.active
  end

  def update
    @node = ComputeNode.find(params[:id])
    if @node.update(node_params)
      redirect_to @node, notice: "Node updated."
    else
      @organizations = Organization.active
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def node_params
    params.require(:compute_node).permit(
      :organization_id, :name, :node_type, :gpu_model, :gpu_vram_mb,
      :region, :grid_zone, :energy_provider, :latitude, :longitude,
      :solana_wallet_address, :status
    )
  end
end
