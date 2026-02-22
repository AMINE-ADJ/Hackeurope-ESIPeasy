class CreateCoreSchema < ActiveRecord::Migration[7.1]
  def change
    # === B2B Organizations (Datacenters, Enterprises) ===
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :org_type, null: false, default: "datacenter" # datacenter, enterprise, gamer
      t.string :api_key_digest
      t.string :stripe_customer_id
      t.string :contact_email
      t.string :tier, default: "starter" # starter, pro, enterprise
      t.boolean :active, default: true
      t.timestamps
    end

    # === Compute Nodes (GPUs from datacenters + B2C gamer rigs) ===
    create_table :compute_nodes do |t|
      t.references :organization, foreign_key: true
      t.string :name, null: false
      t.string :node_type, null: false, default: "datacenter" # datacenter, gamer
      t.string :gpu_model                    # e.g. "A100", "RTX 4090"
      t.integer :gpu_vram_mb                 # VRAM in MB
      t.float :gpu_utilization, default: 0.0 # 0.0 - 1.0
      t.string :region, null: false          # e.g. "eu-west-1", "us-east-1"
      t.string :energy_provider              # e.g. "EDF", "TotalEnergies"
      t.string :grid_zone                    # e.g. "FR", "DE", "US-CAL"
      t.float :latitude
      t.float :longitude
      t.string :status, default: "idle"      # idle, busy, partial, offline
      t.float :current_carbon_intensity      # gCO2/kWh realtime
      t.float :current_energy_price          # EUR/MWh realtime
      t.float :renewable_pct, default: 0.0   # % renewable in local grid
      t.boolean :green_compliant, default: false
      t.string :solana_wallet_address        # B2C gamer payout address
      t.string :crusoe_node_id               # Crusoe API identifier
      t.json :capabilities                   # {"fp16": true, "int8": true, ...}
      t.timestamps
    end
    add_index :compute_nodes, :region
    add_index :compute_nodes, :status
    add_index :compute_nodes, :green_compliant
    add_index :compute_nodes, :grid_zone

    # === AI Workloads (submitted by B2B or marketplace) ===
    create_table :workloads do |t|
      t.references :organization, foreign_key: true
      t.references :compute_node, foreign_key: true, null: true
      t.string :name
      t.string :workload_type, null: false    # inference, training, embedding, fine_tune
      t.string :priority, default: "normal"   # urgent, normal, async (async = green-only)
      t.string :status, default: "pending"    # pending, routing, running, paused, rerouting, completed, failed
      t.float :required_vram_mb
      t.float :max_carbon_intensity           # gCO2/kWh ceiling
      t.float :max_price_per_hour             # EUR/hr ceiling
      t.boolean :green_only, default: false   # only run on green nodes
      t.json :spec                            # {"model": "llama-70b", "batch_size": 32, ...}
      t.string :crusoe_job_id                 # Crusoe inference job ID
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :paused_at
      t.float :estimated_duration_hours
      t.float :actual_cost
      t.float :carbon_saved_grams             # vs worst-case baseline
      t.integer :reroute_count, default: 0
      t.text :routing_log                     # JSON array of routing decisions
      t.timestamps
    end
    add_index :workloads, :status
    add_index :workloads, :priority
    add_index :workloads, :workload_type

    # === Grid States (time-series energy data per zone) ===
    create_table :grid_states do |t|
      t.string :grid_zone, null: false        # "FR", "DE", "US-CAL"
      t.float :carbon_intensity               # gCO2/kWh
      t.float :renewable_pct                  # 0-100
      t.float :energy_price                   # EUR/MWh
      t.float :solar_generation_mw
      t.float :wind_generation_mw
      t.float :demand_mw
      t.float :curtailment_mw                 # wasted renewable energy
      t.string :dominant_source               # solar, wind, nuclear, gas, coal
      t.boolean :surplus_detected, default: false
      t.float :forecast_carbon_1h             # 1-hour-ahead prediction
      t.float :forecast_carbon_6h             # 6-hour-ahead prediction
      t.json :raw_data                        # full API response
      t.datetime :recorded_at, null: false
      t.timestamps
    end
    add_index :grid_states, [:grid_zone, :recorded_at]
    add_index :grid_states, :surplus_detected

    # === Transactions (financial ledger) ===
    create_table :transactions do |t|
      t.references :workload, foreign_key: true
      t.references :organization, foreign_key: true
      t.string :transaction_type, null: false  # charge, payout, fee, refund
      t.decimal :amount, precision: 12, scale: 4
      t.string :currency, default: "EUR"
      t.string :payment_method                 # stripe, solana
      t.string :stripe_payment_intent_id
      t.string :solana_tx_signature
      t.string :status, default: "pending"     # pending, completed, failed
      t.json :paid_ai_metadata                 # Paid.ai profitability data
      t.timestamps
    end
    add_index :transactions, :status
    add_index :transactions, :transaction_type

    # === Routing Decisions (audit trail for Broker Agent) ===
    create_table :routing_decisions do |t|
      t.references :workload, foreign_key: true
      t.references :compute_node, foreign_key: true, null: true
      t.string :decision_type, null: false     # initial_route, reroute, pause, resume
      t.string :reason                         # "carbon_spike", "price_drop", "node_failure", "surplus_detected"
      t.float :carbon_intensity_at_decision
      t.float :energy_price_at_decision
      t.float :renewable_pct_at_decision
      t.float :score                           # composite routing score
      t.json :alternatives_considered          # top-N candidate nodes
      t.json :agent_reasoning                  # incident.io agent trace
      t.timestamps
    end

    # === Carbon Receipts (on-chain proof for B2C) ===
    create_table :carbon_receipts do |t|
      t.references :workload, foreign_key: true
      t.references :compute_node, foreign_key: true
      t.float :carbon_saved_grams
      t.float :renewable_pct_used
      t.float :baseline_carbon_grams           # what it would have been on dirty grid
      t.string :solana_tx_signature
      t.string :solana_mint_address            # NFT mint for receipt
      t.string :status, default: "pending"     # pending, minted, verified
      t.json :proof_data                       # merkle proof data
      t.timestamps
    end

    # === Curtailment Events (ElevenLabs alerts) ===
    create_table :curtailment_events do |t|
      t.string :grid_zone, null: false
      t.float :curtailment_mw
      t.float :potential_savings_eur
      t.float :potential_carbon_savings_g
      t.string :severity, default: "medium"    # low, medium, high, critical
      t.boolean :alert_sent, default: false
      t.string :elevenlabs_audio_url
      t.text :alert_message
      t.datetime :detected_at
      t.datetime :expires_at
      t.timestamps
    end
    add_index :curtailment_events, [:grid_zone, :detected_at]
  end
end
