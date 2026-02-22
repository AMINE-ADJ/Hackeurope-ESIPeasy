# CheckpointService — Pre-emptive checkpointing & live migration
#
# Requirements:
# - Pre-emptive Checkpointing: save workload state before migration
# - State Migration: transfer checkpoint from node A to node B
# - Health Checks: detect degradation and trigger migration
#
# In production, this would interface with CRIU (Checkpoint/Restore In Userspace)
# or GPU-specific checkpoint mechanisms (NVIDIA CUDA checkpoint)
class CheckpointService
  CHECKPOINT_STORAGE = "checkpoint://store" # In production: S3, GCS, etc.

  class << self
    # Checkpoint all running workloads that are due
    def checkpoint_all_due!
      checkpointed = 0
      Workload.running.with_checkpoints.find_each do |workload|
        if workload.needs_checkpoint?
          checkpoint!(workload)
          checkpointed += 1
        end
      end
      Rails.logger.info("[Checkpoint] Checkpointed #{checkpointed} workloads")
      checkpointed
    end

    # Save checkpoint for a specific workload
    def checkpoint!(workload)
      return unless workload.checkpoint_enabled?
      return unless workload.status.in?(%w[running paused migrating])

      checkpoint_url = generate_checkpoint_url(workload)

      # In production: trigger CRIU or CUDA checkpoint
      workload.update!(
        checkpoint_url: checkpoint_url,
        last_checkpoint_at: Time.current
      )

      Rails.logger.info("[Checkpoint] Saved checkpoint for workload #{workload.id} at #{checkpoint_url}")
      { success: true, url: checkpoint_url, timestamp: Time.current }
    end

    # Live migrate a workload from one node to another
    def live_migrate!(workload, target_node, reason: "health_degradation")
      source_node = workload.compute_node
      Rails.logger.info("[Migration] Starting live migration of workload #{workload.id}: #{source_node&.name} → #{target_node.name}")

      # Step 1: Checkpoint current state
      if workload.checkpoint_enabled?
        checkpoint!(workload)
      end

      # Step 2: Perform migration
      workload.migrate_to!(target_node, reason: reason)

      # Step 3: Release old node resources
      if source_node
        source_node.update!(
          status: source_node.workloads.running.exists? ? "busy" : "idle",
          gpu_utilization: [source_node.gpu_utilization - 0.3, 0.0].max
        )
      end

      # Step 4: Update target node
      target_node.update!(
        status: "busy",
        gpu_utilization: [target_node.gpu_utilization + 0.3, 1.0].min
      )

      Rails.logger.info("[Migration] Migration complete for workload #{workload.id}")
      { success: true, from: source_node&.name, to: target_node.name }
    end

    # Check all nodes and trigger migrations for unhealthy ones
    def check_and_migrate!
      migrations = 0
      ComputeNode.where(health_status: %w[degraded critical]).find_each do |node|
        node.workloads.running.find_each do |workload|
          target = find_migration_target(workload, exclude: node)
          if target
            live_migrate!(workload, target, reason: "node_#{node.health_status}")
            migrations += 1
          else
            Rails.logger.warn("[Migration] No migration target for workload #{workload.id} on #{node.name}")
          end
        end
      end
      Rails.logger.info("[Migration] Migrated #{migrations} workloads from unhealthy nodes")
      migrations
    end

    private

    def generate_checkpoint_url(workload)
      "#{CHECKPOINT_STORAGE}/#{workload.id}/#{Time.current.to_i}"
    end

    def find_migration_target(workload, exclude:)
      ComputeNode.available
                 .healthy
                 .where.not(id: exclude.id)
                 .select { |n| n.can_handle?(workload) }
                 .min_by { |n| n.routing_score(workload) }
    end
  end
end
