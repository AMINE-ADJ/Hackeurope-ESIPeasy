class ExtendSchemaForFullPlatform < ActiveRecord::Migration[7.1]
  def change
    # ============================================================
    # 1. USERS TABLE — Multi-tier auth (Gamer, DataCenter, EnergyRecycler, AIDeveloper)
    # ============================================================
    create_table :users do |t|
      t.references :organization, foreign_key: true, null: true
      t.string :email, null: false
      t.string :password_digest
      t.string :name, null: false
      t.string :role, null: false, default: "ai_developer"
      # roles: gamer, datacenter, energy_recycler, ai_developer, admin
      t.string :api_token
      t.boolean :active, default: true
      t.boolean :email_verified, default: false
      t.datetime :last_sign_in_at
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :api_token, unique: true
    add_index :users, :role

    # ============================================================
    # 2. EXTEND ORGANIZATIONS — Add energy_recycler type and metadata
    # ============================================================
    add_column :organizations, :provider_type, :string
    # provider_type: datacenter, gamer, energy_recycler, ai_consumer
    add_column :organizations, :waste_heat_source, :string
    add_column :organizations, :waste_capacity_mw, :float, default: 0.0
    add_column :organizations, :always_green, :boolean, default: false
    add_column :organizations, :onboarding_completed, :boolean, default: false
    add_column :organizations, :verified, :boolean, default: false
    add_column :organizations, :total_carbon_saved_grams, :float, default: 0.0
    add_column :organizations, :total_revenue_earned, :decimal, precision: 12, scale: 4, default: 0

    # ============================================================
    # 3. EXTEND COMPUTE_NODES — Hardware registration, benchmarking, MIG
    # ============================================================
    add_column :compute_nodes, :cooling_type, :string, default: "air"
    # cooling_type: air, liquid, immersion, waste_heat
    add_column :compute_nodes, :cooling_overhead_pct, :float, default: 15.0
    add_column :compute_nodes, :tflops_benchmark, :float
    add_column :compute_nodes, :memory_bandwidth_gbps, :float
    add_column :compute_nodes, :network_latency_ms, :float
    add_column :compute_nodes, :energy_source_type, :string
    # energy_source_type: grid, solar, wind, waste_heat, nuclear, mixed
    add_column :compute_nodes, :pue_ratio, :float, default: 1.2
    # Power Usage Effectiveness (1.0 = perfect)
    add_column :compute_nodes, :mig_enabled, :boolean, default: false
    add_column :compute_nodes, :mig_max_slices, :integer, default: 7
    add_column :compute_nodes, :mig_active_slices, :integer, default: 0
    add_column :compute_nodes, :benchmark_completed, :boolean, default: false
    add_column :compute_nodes, :benchmark_score, :float
    add_column :compute_nodes, :last_health_check_at, :datetime
    add_column :compute_nodes, :health_status, :string, default: "unknown"
    # health_status: healthy, degraded, unhealthy, unknown
    add_column :compute_nodes, :uptime_pct, :float, default: 100.0
    add_column :compute_nodes, :provider_tier, :string
    # provider_tier: recycler, b2b_surplus, b2c_green

    # ============================================================
    # 4. GPU_SLICES — Virtual partitions for underutilized GPUs
    # ============================================================
    create_table :gpu_slices do |t|
      t.references :compute_node, foreign_key: true, null: false
      t.references :workload, foreign_key: true, null: true
      t.string :slice_id, null: false
      # slice_id: e.g. "MIG-1g.10gb", "MIG-2g.20gb", "MIG-3g.40gb"
      t.string :slice_profile, null: false
      # slice_profile: "1g.10gb", "2g.20gb", "3g.40gb", "4g.40gb", "7g.80gb"
      t.integer :vram_mb, null: false
      t.float :compute_units # fraction of total GPU
      t.string :status, default: "available"
      # status: available, allocated, reserved, maintenance
      t.float :utilization, default: 0.0
      t.float :hourly_rate
      t.datetime :allocated_at
      t.datetime :released_at
      t.timestamps
    end
    add_index :gpu_slices, :slice_id, unique: true
    add_index :gpu_slices, :status

    # ============================================================
    # 5. BENCHMARKS — Hardware registration benchmarking results
    # ============================================================
    create_table :benchmarks do |t|
      t.references :compute_node, foreign_key: true, null: false
      t.string :benchmark_type, null: false
      # benchmark_type: tflops, memory_bandwidth, inference_latency, training_throughput
      t.float :score
      t.float :duration_seconds
      t.json :raw_results
      t.string :status, default: "pending"
      # status: pending, running, completed, failed
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    # ============================================================
    # 6. HEALTH_CHECKS — Continuous node health monitoring
    # ============================================================
    create_table :health_checks do |t|
      t.references :compute_node, foreign_key: true, null: false
      t.float :gpu_temp_celsius
      t.float :gpu_utilization
      t.float :memory_utilization
      t.float :power_draw_watts
      t.float :fan_speed_pct
      t.float :network_latency_ms
      t.boolean :gpu_errors_detected, default: false
      t.string :status, null: false, default: "healthy"
      # status: healthy, degraded, critical, offline
      t.json :raw_metrics
      t.timestamps
    end

    # ============================================================
    # 7. EXTEND WORKLOADS — Docker image, budget, checkpointing, green tier
    # ============================================================
    add_column :workloads, :docker_image, :string
    add_column :workloads, :budget_max_eur, :decimal, precision: 12, scale: 4
    add_column :workloads, :green_tier, :string, default: "standard"
    # green_tier: standard, green_preferred, 100_pct_recycled
    add_column :workloads, :checkpoint_enabled, :boolean, default: false
    add_column :workloads, :checkpoint_url, :string
    add_column :workloads, :checkpoint_interval_minutes, :integer, default: 15
    add_column :workloads, :last_checkpoint_at, :datetime
    add_column :workloads, :migrated_from_node_id, :integer
    add_column :workloads, :migration_count, :integer, default: 0
    add_column :workloads, :assigned_gpu_slice_id, :integer
    add_column :workloads, :broker_tier_used, :string
    # broker_tier_used: tier_1_recycler, tier_2_b2b_surplus, tier_3_b2c_green

    # ============================================================
    # 8. PRICING_SNAPSHOTS — Dynamic pricing engine records
    # ============================================================
    create_table :pricing_snapshots do |t|
      t.references :compute_node, foreign_key: true, null: true
      t.string :grid_zone
      t.float :base_rate_eur_per_hour
      t.float :green_premium_pct, default: 0.0
      t.float :surplus_discount_pct, default: 0.0
      t.float :demand_multiplier, default: 1.0
      t.float :final_rate_eur_per_hour
      t.string :pricing_tier
      # pricing_tier: recycler_rate, surplus_rate, green_rate, standard_rate
      t.json :factors
      t.datetime :valid_from
      t.datetime :valid_until
      t.timestamps
    end
    add_index :pricing_snapshots, [:grid_zone, :valid_from]

    # ============================================================
    # 9. EXTEND ROUTING_DECISIONS — Track broker tier
    # ============================================================
    add_column :routing_decisions, :broker_tier, :string
    add_column :routing_decisions, :candidates_per_tier, :json
    add_column :routing_decisions, :migration_triggered, :boolean, default: false

    # ============================================================
    # 10. EXTEND TRANSACTIONS — Settlement tracking
    # ============================================================
    add_column :transactions, :settlement_batch_id, :string
    add_column :transactions, :provider_payout_amount, :decimal, precision: 12, scale: 4
    add_column :transactions, :platform_fee_amount, :decimal, precision: 12, scale: 4
    add_column :transactions, :carbon_credit_amount, :float
    add_column :transactions, :settled_at, :datetime

    # ============================================================
    # 11. EXTEND CURTAILMENT_EVENTS — Link to surplus routing
    # ============================================================
    add_column :curtailment_events, :workloads_routed_count, :integer, default: 0
    add_column :curtailment_events, :energy_captured_mwh, :float, default: 0.0
    add_column :curtailment_events, :revenue_generated_eur, :float, default: 0.0
  end
end
