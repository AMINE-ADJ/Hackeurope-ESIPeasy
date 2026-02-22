# GpuSlicingService — Manages MIG partitioning for underutilized GPUs
#
# Core requirement: "If a B2B GPU is utilized at <70%, the system must
# automatically create a virtual partition (slice) of the remaining 30%+"
#
# This service:
# 1. Monitors GPU utilization across all MIG-capable nodes
# 2. Creates virtual slices when utilization drops below 70%
# 3. Reclaims slices when the primary workload needs capacity back
# 4. Provides slice allocation for the Smart Broker
class GpuSlicingService
  UTILIZATION_THRESHOLD = 0.70 # Slice creation triggers below this
  RECLAIM_THRESHOLD = 0.85     # Start reclaiming slices above this

  class << self
    # Scan all MIG-capable nodes and create/reclaim slices as needed
    def auto_manage!
      results = { sliced: 0, reclaimed: 0, errors: [] }

      ComputeNode.mig_capable.find_each do |node|
        begin
          if node.gpu_utilization.to_f < UTILIZATION_THRESHOLD
            # Underutilized: create slices for remaining capacity
            created = create_slices!(node)
            results[:sliced] += created.size
          elsif node.gpu_utilization.to_f > RECLAIM_THRESHOLD
            # Nearly full: reclaim idle slices
            reclaimed = reclaim_slices!(node)
            results[:reclaimed] += reclaimed
          end
        rescue => e
          results[:errors] << { node: node.name, error: e.message }
          Rails.logger.error("[GpuSlicing] Error on #{node.name}: #{e.message}")
        end
      end

      Rails.logger.info("[GpuSlicing] Auto-manage complete: #{results[:sliced]} sliced, #{results[:reclaimed]} reclaimed")
      results
    end

    # Create slices for a specific node
    def create_slices!(node)
      return [] unless node.mig_enabled?
      return [] if node.gpu_utilization.to_f >= UTILIZATION_THRESHOLD

      # Remove stale available slices first
      node.gpu_slices.available.destroy_all

      slices = GpuSlice.create_slices_for_node!(node)
      if slices.any?
        Rails.logger.info("[GpuSlicing] Created #{slices.size} slices on #{node.name} (utilization: #{(node.gpu_utilization.to_f * 100).round(1)}%)")
        # Broadcast availability for async workloads
        ActionCable.server.broadcast("gpu_slices", {
          event: "slices_available",
          node: node.name,
          zone: node.grid_zone,
          slices: slices.map { |s| { id: s.slice_id, profile: s.slice_profile, vram_mb: s.vram_mb } }
        })
      end
      slices
    end

    # Reclaim slices from a node that needs its capacity back
    def reclaim_slices!(node)
      idle_slices = node.gpu_slices.available
      count = idle_slices.count
      idle_slices.destroy_all
      node.update!(mig_active_slices: node.gpu_slices.count)

      # Migrate workloads off allocated slices if utilization is critical
      if node.gpu_utilization.to_f > 0.95
        node.gpu_slices.allocated.each do |slice|
          next unless slice.workload
          Rails.logger.warn("[GpuSlicing] Reclaiming allocated slice #{slice.slice_id} — migrating workload #{slice.workload.id}")
          slice.workload.migrate_to!(find_alternative_node(slice.workload), reason: "capacity_reclaim")
          slice.release!
        end
      end

      count
    end

    # Find a slice that can handle the given workload
    def find_slice_for(workload)
      GpuSlice.available
              .joins(:compute_node)
              .where("gpu_slices.vram_mb >= ?", workload.required_vram_mb || 0)
              .merge(ComputeNode.available)
              .order(vram_mb: :asc) # Smallest sufficient slice
              .first
    end

    # Allocate a specific slice to a workload
    def allocate_slice!(slice, workload)
      slice.allocate!(workload)
      workload.update!(assigned_gpu_slice_id: slice.id)
      Rails.logger.info("[GpuSlicing] Allocated slice #{slice.slice_id} to workload #{workload.id}")
      slice
    end

    private

    def find_alternative_node(workload)
      ComputeNode.available
                 .where.not(id: workload.compute_node_id)
                 .select { |n| n.can_handle?(workload) }
                 .min_by { |n| n.routing_score(workload) }
    end
  end
end
