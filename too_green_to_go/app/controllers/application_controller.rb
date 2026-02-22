class ApplicationController < ActionController::Base
  private

  # Compute total CO₂ saved: stored value for completed + live estimate for running
  def compute_total_carbon_saved_kg
    # Completed workloads: use stored carbon_saved_grams
    completed_grams = Workload.where(status: "completed").sum(:carbon_saved_grams)

    # Running workloads: compute live estimate based on elapsed time & node intensity
    running_grams = Workload.running.includes(:compute_node).sum do |w|
      w.estimated_carbon_saved_grams
    end

    ((completed_grams + running_grams) / 1000.0).round(2)
  end
end
