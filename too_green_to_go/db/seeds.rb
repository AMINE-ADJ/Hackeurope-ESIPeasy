# db/seeds.rb — Too Green To Go Demo Data
# Run: bin/rails db:seed

puts "🌱 Seeding Too Green To Go..."

# === Organizations ===
puts "  Creating organizations..."

datacenters = [
  { name: "Crusoe Energy (Colorado)", org_type: "datacenter", contact_email: "ops@crusoe.ai", tier: "enterprise", provider_type: "datacenter" },
  { name: "Equinix FR5 (Paris)", org_type: "datacenter", contact_email: "ops@equinix.fr", tier: "enterprise", provider_type: "datacenter" },
  { name: "OVHcloud (Gravelines)", org_type: "datacenter", contact_email: "ops@ovhcloud.com", tier: "pro", provider_type: "datacenter" },
  { name: "Hetzner (Falkenstein)", org_type: "datacenter", contact_email: "ops@hetzner.de", tier: "pro", provider_type: "datacenter" },
  { name: "AWS eu-west-1 (Ireland)", org_type: "datacenter", contact_email: "ops@aws.com", tier: "enterprise", provider_type: "datacenter" },
  { name: "CyrusOne (Texas)", org_type: "datacenter", contact_email: "ops@cyrusone.com", tier: "pro", provider_type: "datacenter" },
]

# AI Consumer organizations
ai_consumers = [
  { name: "Mistral AI", org_type: "ai_consumer", contact_email: "infra@mistral.ai", tier: "enterprise" },
  { name: "Hugging Face", org_type: "ai_consumer", contact_email: "infra@huggingface.co", tier: "enterprise" },
  { name: "LangChain Labs", org_type: "ai_consumer", contact_email: "infra@langchain.dev", tier: "pro" },
]

# Gamer providers (B2C)
gamers = [
  { name: "GreenGamer_Paris", org_type: "gamer", contact_email: "gamer1@proton.me", tier: "starter", provider_type: "gamer" },
  { name: "EcoMiner_Berlin", org_type: "gamer", contact_email: "gamer2@proton.me", tier: "starter", provider_type: "gamer" },
  { name: "SolarRig_Lisbon", org_type: "gamer", contact_email: "gamer3@proton.me", tier: "starter", provider_type: "gamer" },
  { name: "WindPowered_Amsterdam", org_type: "gamer", contact_email: "gamer4@proton.me", tier: "starter", provider_type: "gamer" },
]

# Energy Recycler providers (Tier 1) — always green
energy_recyclers = [
  { name: "WasteHeat Paris", org_type: "energy_recycler", contact_email: "ops@wasteheat.fr", tier: "enterprise", provider_type: "energy_recycler", always_green: true, waste_heat_source: "Industrial process heat from steel manufacturing", waste_capacity_mw: 12.5, verified: true, onboarding_completed: true },
  { name: "BioEnergy Berlin", org_type: "energy_recycler", contact_email: "ops@bioenergy.de", tier: "enterprise", provider_type: "energy_recycler", always_green: true, waste_heat_source: "Biogas plant co-generation", waste_capacity_mw: 8.0, verified: true, onboarding_completed: true },
  { name: "DataHeat Stockholm", org_type: "energy_recycler", contact_email: "ops@dataheat.se", tier: "pro", provider_type: "energy_recycler", always_green: true, waste_heat_source: "District heating waste capture", waste_capacity_mw: 15.0, verified: true, onboarding_completed: true },
]

all_org_data = datacenters + ai_consumers + gamers + energy_recyclers
orgs = all_org_data.map do |attrs|
  Organization.find_or_create_by!(name: attrs[:name]) do |org|
    org.assign_attributes(attrs)
    org.stripe_customer_id = "cus_demo_#{SecureRandom.hex(8)}"
    org.verified = attrs[:verified] || false
    org.onboarding_completed = attrs[:onboarding_completed] || false
  end
end

# === Compute Nodes ===
puts "  Creating compute nodes..."

node_configs = [
  # Datacenter nodes (B2B surplus)
  { org: "Crusoe Energy (Colorado)", name: "crusoe-gpu-01", type: "datacenter", gpu: "H100", vram: 81920, region: "us-west", zone: "FR", provider: "EDF", lat: 39.74, lon: -104.99, mig: true, mig_slices: 7, cooling: "liquid", pue: 1.1 },
  { org: "Crusoe Energy (Colorado)", name: "crusoe-gpu-02", type: "datacenter", gpu: "A100", vram: 40960, region: "us-west", zone: "FR", provider: "EDF", lat: 39.74, lon: -104.99, mig: true, mig_slices: 7, cooling: "liquid", pue: 1.15 },
  { org: "Equinix FR5 (Paris)", name: "eqx-paris-a100-01", type: "datacenter", gpu: "A100", vram: 81920, region: "eu-west", zone: "FR", provider: "EDF", lat: 48.86, lon: 2.35, mig: true, mig_slices: 7, cooling: "air", pue: 1.3 },
  { org: "Equinix FR5 (Paris)", name: "eqx-paris-a100-02", type: "datacenter", gpu: "A100", vram: 40960, region: "eu-west", zone: "FR", provider: "EDF", lat: 48.86, lon: 2.35, cooling: "air", pue: 1.3 },
  { org: "OVHcloud (Gravelines)", name: "ovh-grav-h100-01", type: "datacenter", gpu: "H100", vram: 81920, region: "eu-west", zone: "FR", provider: "EDF", lat: 50.99, lon: 2.12, mig: true, mig_slices: 7, cooling: "immersion", pue: 1.08 },
  { org: "OVHcloud (Gravelines)", name: "ovh-grav-a100-01", type: "datacenter", gpu: "A100", vram: 40960, region: "eu-west", zone: "FR", provider: "EDF", lat: 50.99, lon: 2.12, cooling: "liquid", pue: 1.12 },
  { org: "Hetzner (Falkenstein)", name: "htz-falk-a100-01", type: "datacenter", gpu: "A100", vram: 40960, region: "eu-central", zone: "DE", provider: "EnBW", lat: 50.47, lon: 12.37, mig: true, mig_slices: 7, cooling: "air", pue: 1.25 },
  { org: "Hetzner (Falkenstein)", name: "htz-falk-rtx4090-01", type: "datacenter", gpu: "RTX 4090", vram: 24576, region: "eu-central", zone: "DE", provider: "EnBW", lat: 50.47, lon: 12.37, cooling: "air", pue: 1.3 },
  { org: "AWS eu-west-1 (Ireland)", name: "aws-ire-a100-01", type: "datacenter", gpu: "A100", vram: 40960, region: "eu-west", zone: "NL", provider: "TenneT", lat: 53.35, lon: -6.26, cooling: "liquid", pue: 1.18 },
  { org: "CyrusOne (Texas)", name: "cyrus-tx-h100-01", type: "datacenter", gpu: "H100", vram: 81920, region: "us-east", zone: "DE", provider: "ERCOT", lat: 32.78, lon: -96.80, mig: true, mig_slices: 7, cooling: "liquid", pue: 1.15 },

  # Energy Recycler nodes (Tier 1 — always green)
  { org: "WasteHeat Paris", name: "whp-h100-01", type: "energy_recycler", gpu: "H100", vram: 81920, region: "eu-west", zone: "FR", provider: "WasteHeat", lat: 48.83, lon: 2.27, mig: true, mig_slices: 7, cooling: "waste_heat", pue: 1.02, energy_source: "waste_heat" },
  { org: "WasteHeat Paris", name: "whp-a100-01", type: "energy_recycler", gpu: "A100", vram: 81920, region: "eu-west", zone: "FR", provider: "WasteHeat", lat: 48.83, lon: 2.27, mig: true, mig_slices: 7, cooling: "waste_heat", pue: 1.02, energy_source: "waste_heat" },
  { org: "BioEnergy Berlin", name: "beb-h100-01", type: "energy_recycler", gpu: "H100", vram: 81920, region: "eu-central", zone: "DE", provider: "BioEnergy", lat: 52.48, lon: 13.39, mig: true, mig_slices: 7, cooling: "waste_heat", pue: 1.05, energy_source: "waste_heat" },
  { org: "BioEnergy Berlin", name: "beb-a100-01", type: "energy_recycler", gpu: "A100", vram: 40960, region: "eu-central", zone: "DE", provider: "BioEnergy", lat: 52.48, lon: 13.39, cooling: "waste_heat", pue: 1.05, energy_source: "waste_heat" },
  { org: "DataHeat Stockholm", name: "dhs-h100-01", type: "energy_recycler", gpu: "H100", vram: 81920, region: "eu-north", zone: "SE", provider: "DataHeat", lat: 59.33, lon: 18.07, mig: true, mig_slices: 7, cooling: "waste_heat", pue: 1.03, energy_source: "waste_heat" },
  { org: "DataHeat Stockholm", name: "dhs-h100-02", type: "energy_recycler", gpu: "H100", vram: 81920, region: "eu-north", zone: "SE", provider: "DataHeat", lat: 59.33, lon: 18.07, mig: true, mig_slices: 7, cooling: "waste_heat", pue: 1.03, energy_source: "waste_heat" },

  # Gamer nodes (B2C)
  { org: "GreenGamer_Paris", name: "gamer-paris-4090", type: "gamer", gpu: "RTX 4090", vram: 24576, region: "eu-west", zone: "FR", provider: "EDF", lat: 48.85, lon: 2.29, wallet: "demo_wallet_paris_#{SecureRandom.hex(16)}" },
  { org: "EcoMiner_Berlin", name: "gamer-berlin-3080", type: "gamer", gpu: "RTX 3080", vram: 12288, region: "eu-central", zone: "DE", provider: "EnBW", lat: 52.52, lon: 13.41, wallet: "demo_wallet_berlin_#{SecureRandom.hex(16)}" },
  { org: "SolarRig_Lisbon", name: "gamer-lisbon-4090", type: "gamer", gpu: "RTX 4090", vram: 24576, region: "eu-west", zone: "PT", provider: "EDP", lat: 38.72, lon: -9.14, wallet: "demo_wallet_lisbon_#{SecureRandom.hex(16)}" },
  { org: "WindPowered_Amsterdam", name: "gamer-amsterdam-4090", type: "gamer", gpu: "RTX 4090", vram: 24576, region: "eu-west", zone: "NL", provider: "TenneT", lat: 52.37, lon: 4.90, wallet: "demo_wallet_amsterdam_#{SecureRandom.hex(16)}" },
]

nodes = node_configs.map do |cfg|
  org = Organization.find_by!(name: cfg[:org])
  ComputeNode.find_or_create_by!(name: cfg[:name]) do |node|
    node.organization = org
    node.node_type = cfg[:type]
    node.gpu_model = cfg[:gpu]
    node.gpu_vram_mb = cfg[:vram]
    node.region = cfg[:region]
    node.grid_zone = cfg[:zone]
    node.energy_provider = cfg[:provider]
    node.latitude = cfg[:lat]
    node.longitude = cfg[:lon]
    node.status = %w[idle idle idle partial].sample
    node.gpu_utilization = rand(0.1..0.6).round(2)
    node.solana_wallet_address = cfg[:wallet]
    node.crusoe_node_id = "crusoe_#{SecureRandom.hex(6)}"
    node.capabilities = { fp16: true, int8: cfg[:gpu].include?("H100"), tensor_cores: true }
    node.mig_enabled = cfg[:mig] || false
    node.mig_max_slices = cfg[:mig_slices] || 0
    node.cooling_type = cfg[:cooling] || "air"
    node.pue_ratio = cfg[:pue] || 1.2
    node.energy_source_type = cfg[:energy_source] || "grid_mix"
    node.health_status = "healthy"
    node.benchmark_completed = true
  end
end

# === Run Benchmarks for all nodes ===
puts "  Running benchmarks for all nodes..."
ComputeNode.find_each do |node|
  # Use association to avoid collision with Ruby's Benchmark module
  node.benchmarks.find_or_create_by!(benchmark_type: "full_suite") do |b|
    b.status = "completed"
    b.score = case node.gpu_model
              when "H100" then rand(900..1000).to_f
              when "A100" then rand(280..350).to_f
              when "RTX 4090" then rand(150..180).to_f
              when "RTX 3080" then rand(80..120).to_f
              else rand(100..200).to_f
              end
    b.raw_results = { tflops: b.score, memory_bandwidth_gbps: rand(800..3000), inference_latency_ms: rand(2..15) }
    b.started_at = 1.hour.ago
    b.completed_at = 55.minutes.ago
  end
  node.update!(tflops_benchmark: node.benchmarks.completed.maximum(:score))
end

# === Create GPU Slices for MIG-enabled nodes ===
puts "  Creating GPU slices for MIG nodes..."
ComputeNode.where(mig_enabled: true).each do |node|
  next if node.gpu_slices.any?

  # Create 3-4 slices per MIG node
  profiles = GpuSlice::MIG_PROFILES.keys.sample(rand(3..4))
  profiles.each do |profile|
    vram = GpuSlice::MIG_PROFILES[profile][:vram_mb]
    cu = GpuSlice::MIG_PROFILES[profile][:compute_units]
    GpuSlice.create!(
      compute_node: node,
      slice_id: "mig-#{SecureRandom.hex(6)}",
      slice_profile: profile,
      vram_mb: vram,
      compute_units: cu,
      status: "available"
    )
  end
  puts "    🔪 #{node.name}: #{node.gpu_slices.count} slices created"
end

# === Health Checks ===
puts "  Creating initial health checks..."
ComputeNode.find_each do |node|
  HealthCheck.create!(
    compute_node: node,
    status: "healthy",
    gpu_temp_celsius: rand(35..65).to_f,
    gpu_utilization: node.gpu_utilization,
    memory_utilization: (node.gpu_utilization * rand(0.8..1.0)).round(2),
    power_draw_watts: rand(150..350).to_f,
    fan_speed_pct: rand(20..60).to_f,
    network_latency_ms: rand(1..5).to_f,
    gpu_errors_detected: false,
    raw_metrics: { pcie_gen: 4, driver_version: "535.104.05" }
  )
end

# === Ingest Grid Data ===
puts "  Ingesting grid data for all zones (3 cycles)..."
3.times do |i|
  GridDataService.ingest_all_zones!
  sleep(0.1)
  puts "    Cycle #{i + 1}/3 complete"
end

# Update all nodes with grid data
ComputeNode.find_each(&:update_grid_status!)

# === Create Pricing Snapshots ===
puts "  Creating pricing snapshots..."
ComputeNode.find_each do |node|
  PricingSnapshot.create!(
    compute_node: node,
    grid_zone: node.grid_zone,
    pricing_tier: node.node_type == "energy_recycler" ? "recycler_rate" : node.node_type == "datacenter" ? "surplus_rate" : "green_rate",
    base_rate_eur_per_hour: node.hourly_cost || 2.0,
    green_premium_pct: node.node_type == "energy_recycler" ? 0.0 : 15.0,
    surplus_discount_pct: node.current_energy_price.to_f < 30 ? 30.0 : 0.0,
    demand_multiplier: rand(0.8..1.2).round(2),
    final_rate_eur_per_hour: (node.hourly_cost || 2.0) * rand(0.7..1.1).round(2),
    factors: {
      carbon_intensity: node.current_carbon_intensity || rand(50..200),
      renewable_pct: node.renewable_pct || rand(30..80),
      gpu_utilization: node.gpu_utilization
    },
    valid_from: Time.current,
    valid_until: 1.hour.from_now
  )
end

# === Create Demo Workloads ===
puts "  Creating demo workloads..."

demo_workloads = [
  { org: "Mistral AI", name: "Mistral-7B Fine-tune Batch", type: "fine_tune", priority: "normal", vram: 40960, green: true, green_tier: "100_pct_recycled", duration: 4.0, docker: "mistralai/finetune:latest", budget: 80.0, checkpoint: true },
  { org: "Mistral AI", name: "Embeddings Pipeline v3", type: "embedding", priority: "async", vram: 16384, green: true, green_tier: "green_preferred", duration: 1.5, docker: "mistralai/embed:v3", budget: 25.0, checkpoint: false },
  { org: "Hugging Face", name: "SafeTensors Validation Run", type: "inference", priority: "urgent", vram: 24576, green: false, green_tier: "standard", duration: 0.5, docker: "huggingface/safetensors:latest", budget: 10.0, checkpoint: false },
  { org: "Hugging Face", name: "Model Benchmark Suite", type: "inference", priority: "normal", vram: 81920, green: false, green_tier: "standard", duration: 2.0, docker: "huggingface/bench:v2", budget: 40.0, checkpoint: true },
  { org: "LangChain Labs", name: "RAG Pipeline Inference", type: "inference", priority: "normal", vram: 24576, green: true, green_tier: "green_preferred", duration: 1.0, docker: "langchain/rag:latest", budget: 15.0, checkpoint: false },
  { org: "LangChain Labs", name: "Agent Training v2.1", type: "training", priority: "async", vram: 40960, green: true, green_tier: "100_pct_recycled", duration: 6.0, docker: "langchain/agent-train:v2.1", budget: 120.0, checkpoint: true },
  { org: "Mistral AI", name: "Batch Inference — Classification", type: "batch_inference", priority: "async", vram: 16384, green: true, green_tier: "green_preferred", duration: 3.0, docker: "mistralai/classify:latest", budget: 30.0, checkpoint: false },
]

demo_workloads.each do |cfg|
  org = Organization.find_by!(name: cfg[:org])
  workload = Workload.create!(
    organization: org,
    name: cfg[:name],
    workload_type: cfg[:type],
    priority: cfg[:priority],
    required_vram_mb: cfg[:vram],
    green_only: cfg[:green],
    green_tier: cfg[:green_tier],
    estimated_duration_hours: cfg[:duration],
    max_carbon_intensity: cfg[:green] ? 150 : nil,
    docker_image: cfg[:docker],
    budget_max_eur: cfg[:budget],
    checkpoint_enabled: cfg[:checkpoint],
    checkpoint_interval_minutes: cfg[:checkpoint] ? 30 : nil,
    status: "pending"
  )

  # Route each workload through the tiered broker
  result = BrokerAgentService.new(workload).route!
  if result[:success]
    puts "    ✅ #{cfg[:name]} → #{result[:node].name} (tier: #{result[:tier]}, score: #{result[:score]})"
  else
    puts "    ⏳ #{cfg[:name]} → pending (#{result[:reason]})"
  end
end

# === Simulate some reroutes for demo ===
puts "  Simulating adaptive reroutes..."
running = Workload.running.limit(2)
running.each do |w|
  result = BrokerAgentService.new(w).reroute!(reason: "carbon_spike")
  puts "    🔄 Reroute #{w.name}: #{result[:success] ? 'success' : result[:reason]}"
end

# === Create curtailment events ===
puts "  Creating demo curtailment events..."
CurtailmentEvent.create!(
  grid_zone: "FR",
  curtailment_mw: 850,
  potential_savings_eur: 127.50,
  potential_carbon_savings_g: 170000,
  severity: "critical",
  alert_message: "CRITICAL: 850MW of clean nuclear+solar energy being curtailed in France. Open GPU capacity NOW to capture green compute at ultra-low rates!",
  detected_at: Time.current,
  expires_at: 2.hours.from_now
)

CurtailmentEvent.create!(
  grid_zone: "DE",
  curtailment_mw: 420,
  potential_savings_eur: 63.00,
  potential_carbon_savings_g: 84000,
  severity: "high",
  alert_message: "HIGH: 420MW wind energy surplus in Germany. B2B surplus nodes available for batch workloads.",
  detected_at: 30.minutes.ago,
  expires_at: 3.hours.from_now
)

# === Create completed workload history with financial data ===
puts "  Creating completed workload history..."
tiers = %w[tier_1_recycler tier_2_b2b_surplus tier_3_b2c_green]
12.times do |i|
  org = Organization.where(org_type: "ai_consumer").order("RANDOM()").first
  node = ComputeNode.where(status: %w[idle partial busy]).order("RANDOM()").first
  next unless org && node

  tier = tiers.sample
  duration = rand(1.0..6.0).round(1)
  started = rand(1..72).hours.ago
  completed = started + duration.hours

  w = Workload.create!(
    organization: org,
    compute_node: node,
    name: "Historical Job #{i + 1}",
    workload_type: %w[inference training embedding fine_tune batch_inference].sample,
    priority: "normal",
    status: "completed",
    started_at: started,
    completed_at: completed,
    estimated_duration_hours: duration,
    actual_cost: rand(2..20).to_f.round(2),
    green_tier: %w[standard green_preferred 100_pct_recycled].sample,
    broker_tier_used: tier,
    docker_image: "demo/workload:v#{i + 1}"
  )

  # Now compute and store carbon savings using the model's logic
  w.update_columns(carbon_saved_grams: w.send(:calculate_carbon_savings))
  puts "    📊 #{w.name} → #{node.name}: #{w.carbon_saved_grams}g CO₂ saved (#{duration}h, intensity=#{node.current_carbon_intensity})"

  # Consumer charge
  Transaction.create!(
    workload: w,
    organization: org,
    transaction_type: "charge",
    amount: w.actual_cost * 1.15,
    currency: "EUR",
    payment_method: "stripe",
    stripe_payment_intent_id: "pi_demo_#{SecureRandom.hex(8)}",
    status: "completed"
  )

  # Provider payout
  Transaction.create!(
    workload: w,
    organization: node.organization,
    transaction_type: "payout",
    amount: w.actual_cost * 0.85,
    currency: "EUR",
    payment_method: "stripe",
    stripe_payment_intent_id: "po_demo_#{SecureRandom.hex(8)}",
    status: "completed",
    provider_payout_amount: w.actual_cost * 0.85,
    platform_fee_amount: w.actual_cost * 0.15
  )

  RoutingDecision.create!(
    workload: w,
    compute_node: node,
    decision_type: "initial_route",
    carbon_intensity_at_decision: node.current_carbon_intensity || rand(50..300),
    energy_price_at_decision: node.current_energy_price || rand(20..80),
    renewable_pct_at_decision: node.renewable_pct || rand(30..90),
    score: rand(0.2..0.8).round(4),
    broker_tier: tier
  )
end

# Update carbon saved on organizations
puts "  Updating organization carbon metrics..."
Organization.providers.find_each do |org|
  saved = org.compute_nodes.joins(:workloads).where(workloads: { status: "completed" }).sum("workloads.carbon_saved_grams")
  org.update_columns(total_carbon_saved_grams: saved) if org.respond_to?(:total_carbon_saved_grams)
end

puts ""
puts "✅ Seeding complete!"
puts "   Organizations: #{Organization.count} (#{Organization.providers.count} providers, #{Organization.where(org_type: 'ai_consumer').count} consumers)"
puts "   Compute Nodes: #{ComputeNode.count} (#{ComputeNode.recycler_nodes.count} recyclers, #{ComputeNode.mig_capable.count} MIG)"
puts "   GPU Slices:    #{GpuSlice.count} (#{GpuSlice.available.count} available)"
puts "   Benchmarks:    #{GpuBenchmark.count}"
puts "   Health Checks: #{HealthCheck.count}"
puts "   Grid States:   #{GridState.count}"
puts "   Workloads:     #{Workload.count} (#{Workload.running.count} running, #{Workload.where(status: 'completed').count} completed)"
puts "   Transactions:  #{Transaction.count}"
puts "   Routing Decisions: #{RoutingDecision.count}"
puts "   Curtailment Events: #{CurtailmentEvent.count}"
puts "   Pricing Snapshots: #{PricingSnapshot.count}"
puts ""
puts "🚀 Run `bin/rails server` and visit http://localhost:3000"
