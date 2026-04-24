# 🌿 Too Green To Go

**The Energy-Aware GPU Arbitrage Platform**

> *Turn wasted clean energy into AI compute power. The greenest compute wins.*

Too Green To Go is a full-stack platform that monitors real-time energy grids across **11 zones** (EU + US), scores GPU nodes on a composite carbon-price-utilization metric, and **automatically routes AI workloads** to wherever clean energy is cheapest — in real-time. When the grid shifts, an adaptive agent **reroutes workloads mid-execution** to stay on green power.

---

## 📋 Table of Contents

- [The Problem](#-the-problem)
- [The Solution](#-the-solution)
- [How It Works](#-how-it-works)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Database Schema](#-database-schema)
- [Backend Services](#-backend-services)
- [API Reference](#-api-reference)
- [Frontend Pages](#-frontend-pages)
- [Getting Started](#-getting-started)
- [Key Metrics](#-key-metrics)

---

## 🔥 The Problem

Two massive market failures exist simultaneously:

1. **Wasted Clean Energy** — 30% of renewable energy in Europe gets curtailed because there's no demand-side flexibility. Wind turbines spin with nowhere to send power. Solar farms overproduce at midday with no buyers.

2. **Overpriced Dirty Compute** — Data centers three countries over run LLM inference on coal-powered grids at premium prices. AI companies pay top dollar for GPU time that could be 40% cheaper on a surplus green grid.

This mismatch is a **$47 billion problem**. The AI compute market is $150B and growing 40% annually, while clean energy is literally being thrown away.

---

## 💡 The Solution

Too Green To Go sits at the intersection of **energy markets** and **GPU compute markets**:

- **Real-time grid monitoring** across 11 zones — carbon intensity, renewable percentage, spot prices — updated every 30 seconds
- **Smart broker agent** that scores every GPU node: `60% carbon + 30% price + 10% utilization`
- **Adaptive routing** — when the grid shifts (cloud covers solar in Spain, wind picks up in the North Sea), workloads are **rerouted mid-execution** to stay green
- **Three-tier priority system**: Energy Recyclers → Surplus Data Centers → Green Gamers
- **MIG GPU slicing** — underutilized GPUs (<70%) are fractionally split and sub-leased
- **Carbon receipts** — every completed workload generates verifiable proof of green compute

### Business Model

| Side | How it works | Revenue |
|------|-------------|---------|
| **B2B** | Enterprises (Mistral AI, Hugging Face) submit workloads. Billed via Stripe with metered usage. | 15% platform fee |
| **B2C** | Gamers with spare RTX 4090s plug into the network. When their local grid goes surplus, inference jobs are sent to their GPU. | Instant payouts via Solana |

---

## ⚙️ How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│  AI Developer submits workload (Docker image + VRAM + budget)   │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              BROKER AGENT SERVICE (3-Tier Router)                │
│                                                                 │
│  1. Green Compliance Engine → filter eligible nodes             │
│  2. Categorize by tier:                                         │
│       Tier 1: Energy Recyclers (waste heat, always green)       │
│       Tier 2: B2B Data Centers (surplus/curtailment windows)    │
│       Tier 3: B2C Gamers (local grid >50% renewable)           │
│  3. Score candidates: 60% carbon + 30% price + 10% utilization │
│  4. Route to best node. Start workload.                         │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              ADAPTIVE MONITORING (Continuous)                    │
│                                                                 │
│  • Grid state changes detected (carbon spike, price drop)      │
│  • Reroute threshold exceeded (>25% score degradation)         │
│  • Checkpoint workload → migrate to better node                │
│  • Up to 5 reroutes per workload                               │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              SETTLEMENT                                         │
│                                                                 │
│  • Stripe charges B2B customer                                  │
│  • Solana pays B2C gamer provider                              │
│  • Carbon receipt minted (verifiable proof of green compute)    │
│  • Profitability report generated                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Architecture

```
┌──────────────────────┐         ┌──────────────────────────────┐
│     FRONTEND         │         │          BACKEND              │
│   React + Vite       │  proxy  │      Ruby on Rails 7.1       │
│   Port 8080          │────────▶│      Port 3000               │
│                      │  /api/* │                              │
│  • shadcn/ui         │         │  • 14 DB models              │
│  • TanStack Query    │         │  • 12 services               │
│  • Recharts          │         │  • RESTful JSON API          │
│  • React Router      │         │  • SQLite3                   │
│  • Tailwind CSS      │         │  • Puma server               │
└──────────────────────┘         └──────────────────────────────┘
```

The frontend communicates with the backend exclusively through a **RESTful JSON API** under `/api/v1/`. The Vite dev server proxies all `/api/*` requests to the Rails backend, enabling seamless local development on separate ports.

React Query hooks with **auto-refresh intervals** (8–20 seconds per endpoint) provide a live-updating dashboard feel where metrics, GPU telemetry, and job statuses update automatically without page reloads.

---

## 🛠️ Tech Stack

### Backend
| Technology | Purpose |
|-----------|---------|
| **Ruby on Rails 7.1.6** | API framework, MVC structure, ActiveRecord ORM |
| **Ruby 3.0.2** | Language runtime |
| **SQLite3** | Database (lightweight, zero-config for demo) |
| **Puma** | Concurrent web server |
| **rack-cors** | Cross-origin API access for frontend |
| **Sidekiq** | Background job processing (async rerouting, health checks) |
| **Stripe** | B2B payment processing, metered billing |
| **HTTParty** | External API calls (grid data, Crusoe inference) |

### Frontend
| Technology | Purpose |
|-----------|---------|
| **React 18** | UI framework |
| **TypeScript** | Type safety across the entire frontend |
| **Vite** | Build tool & dev server (port 8080) |
| **shadcn/ui** | 49 accessible UI components (Radix primitives + Tailwind) |
| **Tailwind CSS** | Utility-first styling with green-themed design tokens |
| **TanStack React Query** | Server state management, caching, auto-refresh |
| **React Router v6** | Client-side routing |
| **Recharts** | Data visualization (area charts, line charts) |
| **Lucide React** | Icon library |

### Design
| Element | Value |
|---------|-------|
| Primary color | `hsl(160, 84%, 39%)` — green |
| Fonts | Space Grotesk (headings) + Inter (body) |
| Theme | Dark mode with green accents |

---

## 📁 Project Structure

```
Unaite/
├── frontend/                    # React + Vite + TypeScript
│   ├── src/
│   │   ├── pages/               # 10 route pages
│   │   │   ├── Index.tsx        # Landing page with live stats
│   │   │   ├── Dashboard.tsx    # Main dashboard (stats, events, GPU fleet)
│   │   │   ├── Marketplace.tsx  # GPU marketplace with deploy action
│   │   │   ├── Jobs.tsx         # Submit & monitor AI workloads
│   │   │   ├── Telemetry.tsx    # GPU metrics & MIG slicing view
│   │   │   ├── Heatmap.tsx      # Global energy heatmap by region
│   │   │   ├── Sustainability.tsx # CO₂ offset, pricing, transactions
│   │   │   ├── AdminOverride.tsx  # Crusoe waste event declaration
│   │   │   └── Onboarding.tsx   # Provider registration + benchmark
│   │   ├── lib/
│   │   │   └── api.ts           # TypeScript API client (~400 lines)
│   │   ├── hooks/
│   │   │   └── useApi.ts        # React Query hooks for all endpoints
│   │   ├── components/
│   │   │   ├── DashboardLayout.tsx  # Sidebar + topbar layout shell
│   │   │   ├── AppSidebar.tsx       # Role-filtered navigation
│   │   │   ├── TopBar.tsx           # Role switcher dropdown
│   │   │   ├── LoadingState.tsx     # Loading/error UI components
│   │   │   └── ui/                  # 49 shadcn/ui components
│   │   ├── contexts/
│   │   │   └── RoleContext.tsx   # 5 roles: gamer|datacenter|recycler|developer|admin
│   │   └── data/
│   │       └── mockData.ts      # Original mock data (no longer imported by pages)
│   ├── vite.config.ts           # Proxy config: /api → localhost:3000
│   └── package.json
│
└── too_green_to_go/             # Ruby on Rails 7.1 backend
    ├── app/
    │   ├── controllers/
    │   │   └── api/v1/          # 8 JSON API controllers
    │   │       ├── dashboard_controller.rb
    │   │       ├── marketplace_controller.rb
    │   │       ├── telemetry_controller.rb
    │   │       ├── heatmap_controller.rb
    │   │       ├── sustainability_controller.rb
    │   │       ├── admin_controller.rb
    │   │       ├── onboarding_controller.rb
    │   │       └── workloads_controller.rb
    │   ├── models/              # 14 ActiveRecord models
    │   │   ├── organization.rb
    │   │   ├── compute_node.rb
    │   │   ├── workload.rb
    │   │   ├── grid_state.rb
    │   │   ├── gpu_slice.rb
    │   │   ├── routing_decision.rb
    │   │   ├── curtailment_event.rb
    │   │   ├── carbon_receipt.rb
    │   │   ├── pricing_snapshot.rb
    │   │   ├── health_check.rb
    │   │   ├── transaction.rb
    │   │   ├── user.rb
    │   │   ├── gpu_benchmark.rb
    │   │   └── gpu_slice.rb
    │   └── services/            # 12 domain services
    │       ├── broker_agent_service.rb
    │       ├── green_compliance_engine.rb
    │       ├── grid_data_service.rb
    │       ├── dynamic_pricing_service.rb
    │       ├── gpu_slicing_service.rb
    │       ├── checkpoint_service.rb
    │       ├── incident_agent_service.rb
    │       ├── crusoe_inference_service.rb
    │       ├── stripe_service.rb
    │       ├── solana_service.rb
    │       ├── eleven_labs_service.rb
    │       └── paid_ai_service.rb
    ├── config/
    │   ├── routes.rb            # All HTML + API routes
    │   └── initializers/
    │       └── cors.rb          # CORS for frontend origins
    └── db/
        ├── schema.rb            # 14 tables, 322 lines
        └── seeds.rb             # 13 orgs, 20 nodes, demo workloads
```

---

## 🗄️ Database Schema

14 tables modelling the complete energy-aware compute marketplace:

| Table | Purpose | Key Fields |
|-------|---------|------------|
| **organizations** | Provider companies & AI consumers | `org_type`, `tier`, `total_carbon_saved_grams`, `always_green` |
| **compute_nodes** | GPUs in the fleet (DC, gamer, recycler) | `gpu_model`, `gpu_vram_mb`, `grid_zone`, `renewable_pct`, `mig_enabled`, `health_status` |
| **workloads** | AI jobs submitted by developers | `workload_type`, `green_only`, `budget_max_eur`, `carbon_saved_grams`, `broker_tier_used` |
| **grid_states** | Real-time energy snapshots per zone | `carbon_intensity`, `renewable_pct`, `energy_price`, `surplus_detected`, `curtailment_mw` |
| **routing_decisions** | Audit trail for every routing choice | `score`, `broker_tier`, `alternatives_considered`, `agent_reasoning` |
| **gpu_slices** | MIG fractional GPU allocations | `slice_profile`, `vram_mb`, `compute_units`, `hourly_rate` |
| **curtailment_events** | Detected energy waste events | `curtailment_mw`, `severity`, `workloads_routed_count`, `revenue_generated_eur` |
| **pricing_snapshots** | Dynamic pricing over time | `base_rate_eur_per_hour`, `green_premium_pct`, `surplus_discount_pct`, `demand_multiplier` |
| **carbon_receipts** | On-chain proof of green compute | `carbon_saved_grams`, `renewable_pct_used`, `solana_tx_signature` |
| **transactions** | Financial settlement records | `amount`, `stripe_payment_intent_id`, `solana_tx_signature`, `platform_fee_amount` |
| **health_checks** | GPU health monitoring | `gpu_temp_celsius`, `gpu_utilization`, `memory_utilization`, `power_draw_watts` |
| **benchmarks** | GPU performance validation | `benchmark_type`, `score`, `raw_results` |
| **users** | Platform users with roles | `role`, `api_token`, `organization_id` |

---

## 🔧 Backend Services

### BrokerAgentService — *The Core*
The smart router that powers the entire platform. 420+ lines implementing:

- **3-Tier Priority Matching**: Energy Recyclers (always-green) → B2B Surplus DCs (curtailment windows) → B2C Gamers (green local grids)
- **Composite Scoring**: `0.6 × carbon + 0.3 × price + 0.1 × utilization` — normalized across all candidates
- **GPU Slice Fallback**: If no full node matches VRAM requirements, attempts to allocate a MIG slice
- **Adaptive Rerouting**: Monitors for score degradation >25%, triggers checkpoint + live migration (max 5 reroutes)
- **Full Decision Audit**: Every routing decision logged with alternatives considered, agent reasoning, and tier breakdown

### GreenComplianceEngine
Filters nodes by carbon compliance rules:
- Validates renewable percentage thresholds per tier
- Checks grid zone surplus status
- Enforces `green_only` workload constraints
- Returns only nodes that pass all compliance gates

### GridDataService
Manages energy grid data for 11 zones:
- **EU**: FR, DE, ES, PT, NL, BE, IT, GB
- **US**: US-CAL-CISO, US-NY-NYIS, US-TEX-ERCO
- Tracks carbon intensity, renewable percentage, spot prices, dominant source
- Detects surplus conditions and curtailment windows

### DynamicPricingService
Calculates real-time GPU pricing based on:
- Base rate per GPU model (H100: €2.40/hr, A100: €1.50/hr, RTX 4090: €0.40/hr)
- Green premium (10-25% markup for certified green compute)
- Surplus discount (up to 40% off during curtailment)
- Demand multiplier (1.0x–2.5x based on queue depth)

### GpuSlicingService
Implements NVIDIA MIG (Multi-Instance GPU) slicing:
- Detects underutilized GPUs (<70% SM utilization)
- Splits into fractional slices (up to 7 per GPU)
- Each slice has independent VRAM, compute units, and pricing
- Auto-releases slices when workloads complete

### CheckpointService
Enables live workload migration:
- Periodic checkpointing at configurable intervals (default: 15 min)
- Saves workload state to checkpoint URL
- Enables zero-downtime migration when rerouting to a greener node

### Other Services
| Service | Purpose |
|---------|---------|
| **IncidentAgentService** | State machine for anomaly detection — monitors grid shifts and triggers reroutes |
| **CrusoeInferenceService** | Workload complexity evaluation via Crusoe's inference API |
| **StripeService** | B2B metered billing — creates payment intents, tracks usage |
| **SolanaService** | B2C instant payouts to gamer wallets + carbon receipt NFT minting |
| **ElevenLabsService** | Audio alert generation for curtailment events |
| **PaidAiService** | Per-workload profitability tracking and reporting |

---

## 📡 API Reference

All endpoints are under `/api/v1/` and return JSON.

### Dashboard
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/dashboard` | Aggregate stats, surplus events, energy providers, jobs, GPU fleet |

**Response shape:**
```json
{
  "stats": { "co2_saved": "6.76 kg", "gpu_hours_brokered": "35.7", "active_providers": 13, ... },
  "surplus_events": [...],
  "energy_providers": [{ "name": "EDF", "region": "FR", "carbon_intensity": 56.5, "status": "green", ... }],
  "jobs": [{ "id": "WKL-023", "name": "Mistral-7B Fine-tune", "status": "running", "progress": 45, ... }],
  "gpu_fleet": [{ "gpu": "H100", "name": "crusoe-gpu-01", "sm_util": 72, "temp": 59, ... }]
}
```

### Marketplace
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/marketplace` | GPU listings with green scores, pricing, availability |
| `POST` | `/api/v1/marketplace/:id/deploy` | Deploy a workload on a specific node |

### Workloads (Jobs)
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/workloads` | List all workloads |
| `POST` | `/api/v1/workloads` | Submit a new workload |
| `POST` | `/api/v1/workloads/:id/route` | Route workload via Broker Agent |
| `POST` | `/api/v1/workloads/:id/complete` | Mark workload as completed |

### Telemetry
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/telemetry` | GPU metrics + 24h utilization history |

### Heatmap
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/heatmap` | Regions with lat/lng, carbon, prices, surplus events |

### Sustainability
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/sustainability` | CO₂ stats, 30-day pricing history, transactions |

### Admin (Crusoe Override)
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/admin` | Waste events, cluster overview |
| `POST` | `/api/v1/admin/declare_waste_event` | Manually declare surplus energy → spin up GPUs |
| `POST` | `/api/v1/admin/override_routing` | Manual admin routing override |

### Onboarding
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/onboarding/register` | Register a new provider (gamer/DC/recycler) |
| `POST` | `/api/v1/onboarding/benchmark` | Run GPU benchmark with model-specific results |

---

## 🖥️ Frontend Pages

The frontend supports **5 user roles** with role-filtered navigation:

| Role | View | Description |
|------|------|-------------|
| **Developer** | Dashboard, Jobs, Marketplace, Sustainability | Submit workloads, monitor progress, track costs |
| **Datacenter** | Dashboard, Marketplace, Telemetry, Onboarding, Sustainability | Manage GPU fleet, monitor utilization |
| **Gamer** | Dashboard, Marketplace, Onboarding, Sustainability | Register GPU, earn from surplus compute |
| **Recycler** | Dashboard, Heatmap, Admin Override, Onboarding, Sustainability | Declare waste events, manage stranded energy |
| **Admin** | All pages | Full platform access |

### Page Details

| Page | Data Source | Live Features |
|------|-------------|---------------|
| **Dashboard** | `useDashboard()` — 10s refresh | Stats update as workloads complete, surplus events appear in real-time |
| **Marketplace** | `useMarketplace()` — 15s refresh | Deploy button creates workload + routes via Broker Agent, toast notifications |
| **Jobs** | `useJobs()` — 8s refresh | Submit form → `POST /workloads` → auto-route, status/progress live update |
| **Telemetry** | `useTelemetry()` — 10s refresh | 24h utilization chart, MIG slice bars, underutilization detection |
| **Heatmap** | `useHeatmap()` — 12s refresh | 11 region cards with price/carbon, provider data, surplus feed |
| **Sustainability** | `useSustainability()` — 20s refresh | Dynamic pricing chart (30d), transaction history, CO₂ offset tracking |
| **Admin Override** | `useAdmin()` — 10s refresh | Declare waste events via API, live cluster overview with node counts |
| **Onboarding** | Mutations only | Multi-step form: register → benchmark (with simulated progress bar) → results |

---

## 🚀 Getting Started

### Prerequisites

- **Ruby** 3.0+ with Bundler
- **Node.js** 18+ with npm
- **SQLite3**

### 1. Clone the repository

```bash
git clone https://github.com/AMINE-ADJ/Hackeurope-ESIPeasy.git
cd Hackeurope-ESIPeasy
```

### 2. Start the backend

```bash
cd too_green_to_go
bundle install
rails db:create db:migrate db:seed
rails server -b 0.0.0.0 -p 3000
```

This seeds the database with:
- 13 organizations (datacenters, gamers, recyclers, AI consumers)
- 20 compute nodes across 11 grid zones
- Historical workloads with calculated carbon savings
- Pricing snapshots and grid state data

### 3. Start the frontend

```bash
cd frontend
npm install
npm run dev
```

### 4. Open the app

Visit **http://localhost:8080** in your browser.

The Vite dev server proxies all `/api/*` requests to the Rails backend at `localhost:3000`. Both servers must be running.

---

## 📊 Key Metrics

| Metric | Value | Context |
|--------|-------|---------|
| Carbon saved | 25-60% reduction | vs. baseline grid allocation |
| Cost reduction | 15-30% | energy arbitrage + surplus capture |
| Grid zones | 11 | FR, DE, ES, PT, NL, BE, IT, GB, US-CAL, US-NY, US-TX |
| GPU fleet | 20 nodes | H100, A100, RTX 4090, RTX 3080 |
| Organization types | 4 | Datacenter, Gamer, Energy Recycler, AI Consumer |
| API endpoints | 15+ | Full RESTful JSON API |
| Auto-refresh | 8-20s | Live-updating dashboards via React Query |
| Broker scoring | 3 tiers | 60% carbon, 30% price, 10% utilization |
| MIG slicing | 7 slices/GPU | Fractional allocation at <70% utilization |

---

[![Watch the DEMO](https://img.youtube.com/vi/bAB5XDTxCcs/maxresdefault.jpg)](https://youtu.be/bAB5XDTxCcs)


## 👥 Team

Built at **HackEurope** — the entire platform engineered in a single weekend.

---

*Too Green To Go — because the greenest compute wins.* 🌿
