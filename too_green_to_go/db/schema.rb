# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_02_22_000002) do
  create_table "benchmarks", force: :cascade do |t|
    t.integer "compute_node_id", null: false
    t.string "benchmark_type", null: false
    t.float "score"
    t.float "duration_seconds"
    t.json "raw_results"
    t.string "status", default: "pending"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["compute_node_id"], name: "index_benchmarks_on_compute_node_id"
  end

  create_table "carbon_receipts", force: :cascade do |t|
    t.integer "workload_id"
    t.integer "compute_node_id"
    t.float "carbon_saved_grams"
    t.float "renewable_pct_used"
    t.float "baseline_carbon_grams"
    t.string "solana_tx_signature"
    t.string "solana_mint_address"
    t.string "status", default: "pending"
    t.json "proof_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["compute_node_id"], name: "index_carbon_receipts_on_compute_node_id"
    t.index ["workload_id"], name: "index_carbon_receipts_on_workload_id"
  end

  create_table "compute_nodes", force: :cascade do |t|
    t.integer "organization_id"
    t.string "name", null: false
    t.string "node_type", default: "datacenter", null: false
    t.string "gpu_model"
    t.integer "gpu_vram_mb"
    t.float "gpu_utilization", default: 0.0
    t.string "region", null: false
    t.string "energy_provider"
    t.string "grid_zone"
    t.float "latitude"
    t.float "longitude"
    t.string "status", default: "idle"
    t.float "current_carbon_intensity"
    t.float "current_energy_price"
    t.float "renewable_pct", default: 0.0
    t.boolean "green_compliant", default: false
    t.string "solana_wallet_address"
    t.string "crusoe_node_id"
    t.json "capabilities"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cooling_type", default: "air"
    t.float "cooling_overhead_pct", default: 15.0
    t.float "tflops_benchmark"
    t.float "memory_bandwidth_gbps"
    t.float "network_latency_ms"
    t.string "energy_source_type"
    t.float "pue_ratio", default: 1.2
    t.boolean "mig_enabled", default: false
    t.integer "mig_max_slices", default: 7
    t.integer "mig_active_slices", default: 0
    t.boolean "benchmark_completed", default: false
    t.float "benchmark_score"
    t.datetime "last_health_check_at"
    t.string "health_status", default: "unknown"
    t.float "uptime_pct", default: 100.0
    t.string "provider_tier"
    t.index ["green_compliant"], name: "index_compute_nodes_on_green_compliant"
    t.index ["grid_zone"], name: "index_compute_nodes_on_grid_zone"
    t.index ["organization_id"], name: "index_compute_nodes_on_organization_id"
    t.index ["region"], name: "index_compute_nodes_on_region"
    t.index ["status"], name: "index_compute_nodes_on_status"
  end

  create_table "curtailment_events", force: :cascade do |t|
    t.string "grid_zone", null: false
    t.float "curtailment_mw"
    t.float "potential_savings_eur"
    t.float "potential_carbon_savings_g"
    t.string "severity", default: "medium"
    t.boolean "alert_sent", default: false
    t.string "elevenlabs_audio_url"
    t.text "alert_message"
    t.datetime "detected_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "workloads_routed_count", default: 0
    t.float "energy_captured_mwh", default: 0.0
    t.float "revenue_generated_eur", default: 0.0
    t.index ["grid_zone", "detected_at"], name: "index_curtailment_events_on_grid_zone_and_detected_at"
  end

  create_table "gpu_slices", force: :cascade do |t|
    t.integer "compute_node_id", null: false
    t.integer "workload_id"
    t.string "slice_id", null: false
    t.string "slice_profile", null: false
    t.integer "vram_mb", null: false
    t.float "compute_units"
    t.string "status", default: "available"
    t.float "utilization", default: 0.0
    t.float "hourly_rate"
    t.datetime "allocated_at"
    t.datetime "released_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["compute_node_id"], name: "index_gpu_slices_on_compute_node_id"
    t.index ["slice_id"], name: "index_gpu_slices_on_slice_id", unique: true
    t.index ["status"], name: "index_gpu_slices_on_status"
    t.index ["workload_id"], name: "index_gpu_slices_on_workload_id"
  end

  create_table "grid_states", force: :cascade do |t|
    t.string "grid_zone", null: false
    t.float "carbon_intensity"
    t.float "renewable_pct"
    t.float "energy_price"
    t.float "solar_generation_mw"
    t.float "wind_generation_mw"
    t.float "demand_mw"
    t.float "curtailment_mw"
    t.string "dominant_source"
    t.boolean "surplus_detected", default: false
    t.float "forecast_carbon_1h"
    t.float "forecast_carbon_6h"
    t.json "raw_data"
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["grid_zone", "recorded_at"], name: "index_grid_states_on_grid_zone_and_recorded_at"
    t.index ["surplus_detected"], name: "index_grid_states_on_surplus_detected"
  end

  create_table "health_checks", force: :cascade do |t|
    t.integer "compute_node_id", null: false
    t.float "gpu_temp_celsius"
    t.float "gpu_utilization"
    t.float "memory_utilization"
    t.float "power_draw_watts"
    t.float "fan_speed_pct"
    t.float "network_latency_ms"
    t.boolean "gpu_errors_detected", default: false
    t.string "status", default: "healthy", null: false
    t.json "raw_metrics"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["compute_node_id"], name: "index_health_checks_on_compute_node_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "org_type", default: "datacenter", null: false
    t.string "api_key_digest"
    t.string "stripe_customer_id"
    t.string "contact_email"
    t.string "tier", default: "starter"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider_type"
    t.string "waste_heat_source"
    t.float "waste_capacity_mw", default: 0.0
    t.boolean "always_green", default: false
    t.boolean "onboarding_completed", default: false
    t.boolean "verified", default: false
    t.float "total_carbon_saved_grams", default: 0.0
    t.decimal "total_revenue_earned", precision: 12, scale: 4, default: "0.0"
  end

  create_table "pricing_snapshots", force: :cascade do |t|
    t.integer "compute_node_id"
    t.string "grid_zone"
    t.float "base_rate_eur_per_hour"
    t.float "green_premium_pct", default: 0.0
    t.float "surplus_discount_pct", default: 0.0
    t.float "demand_multiplier", default: 1.0
    t.float "final_rate_eur_per_hour"
    t.string "pricing_tier"
    t.json "factors"
    t.datetime "valid_from"
    t.datetime "valid_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["compute_node_id"], name: "index_pricing_snapshots_on_compute_node_id"
    t.index ["grid_zone", "valid_from"], name: "index_pricing_snapshots_on_grid_zone_and_valid_from"
  end

  create_table "routing_decisions", force: :cascade do |t|
    t.integer "workload_id"
    t.integer "compute_node_id"
    t.string "decision_type", null: false
    t.string "reason"
    t.float "carbon_intensity_at_decision"
    t.float "energy_price_at_decision"
    t.float "renewable_pct_at_decision"
    t.float "score"
    t.json "alternatives_considered"
    t.json "agent_reasoning"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "broker_tier"
    t.json "candidates_per_tier"
    t.boolean "migration_triggered", default: false
    t.index ["compute_node_id"], name: "index_routing_decisions_on_compute_node_id"
    t.index ["workload_id"], name: "index_routing_decisions_on_workload_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "workload_id"
    t.integer "organization_id"
    t.string "transaction_type", null: false
    t.decimal "amount", precision: 12, scale: 4
    t.string "currency", default: "EUR"
    t.string "payment_method"
    t.string "stripe_payment_intent_id"
    t.string "solana_tx_signature"
    t.string "status", default: "pending"
    t.json "paid_ai_metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "settlement_batch_id"
    t.decimal "provider_payout_amount", precision: 12, scale: 4
    t.decimal "platform_fee_amount", precision: 12, scale: 4
    t.float "carbon_credit_amount"
    t.datetime "settled_at"
    t.index ["organization_id"], name: "index_transactions_on_organization_id"
    t.index ["status"], name: "index_transactions_on_status"
    t.index ["transaction_type"], name: "index_transactions_on_transaction_type"
    t.index ["workload_id"], name: "index_transactions_on_workload_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "organization_id"
    t.string "email", null: false
    t.string "password_digest"
    t.string "name", null: false
    t.string "role", default: "ai_developer", null: false
    t.string "api_token"
    t.boolean "active", default: true
    t.boolean "email_verified", default: false
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "workloads", force: :cascade do |t|
    t.integer "organization_id"
    t.integer "compute_node_id"
    t.string "name"
    t.string "workload_type", null: false
    t.string "priority", default: "normal"
    t.string "status", default: "pending"
    t.float "required_vram_mb"
    t.float "max_carbon_intensity"
    t.float "max_price_per_hour"
    t.boolean "green_only", default: false
    t.json "spec"
    t.string "crusoe_job_id"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "paused_at"
    t.float "estimated_duration_hours"
    t.float "actual_cost"
    t.float "carbon_saved_grams"
    t.integer "reroute_count", default: 0
    t.text "routing_log"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "docker_image"
    t.decimal "budget_max_eur", precision: 12, scale: 4
    t.string "green_tier", default: "standard"
    t.boolean "checkpoint_enabled", default: false
    t.string "checkpoint_url"
    t.integer "checkpoint_interval_minutes", default: 15
    t.datetime "last_checkpoint_at"
    t.integer "migrated_from_node_id"
    t.integer "migration_count", default: 0
    t.integer "assigned_gpu_slice_id"
    t.string "broker_tier_used"
    t.index ["compute_node_id"], name: "index_workloads_on_compute_node_id"
    t.index ["organization_id"], name: "index_workloads_on_organization_id"
    t.index ["priority"], name: "index_workloads_on_priority"
    t.index ["status"], name: "index_workloads_on_status"
    t.index ["workload_type"], name: "index_workloads_on_workload_type"
  end

  add_foreign_key "benchmarks", "compute_nodes"
  add_foreign_key "carbon_receipts", "compute_nodes"
  add_foreign_key "carbon_receipts", "workloads"
  add_foreign_key "compute_nodes", "organizations"
  add_foreign_key "gpu_slices", "compute_nodes"
  add_foreign_key "gpu_slices", "workloads"
  add_foreign_key "health_checks", "compute_nodes"
  add_foreign_key "pricing_snapshots", "compute_nodes"
  add_foreign_key "routing_decisions", "compute_nodes"
  add_foreign_key "routing_decisions", "workloads"
  add_foreign_key "transactions", "organizations"
  add_foreign_key "transactions", "workloads"
  add_foreign_key "users", "organizations"
  add_foreign_key "workloads", "compute_nodes"
  add_foreign_key "workloads", "organizations"
end
