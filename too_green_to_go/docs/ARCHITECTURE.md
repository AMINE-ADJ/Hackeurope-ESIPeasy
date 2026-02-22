# Too Green To Go — Architecture & Technical Blueprint

## Vision
**Energy-aware GPU arbitrage platform** that routes AI workloads to wherever clean energy is cheapest — turning grid surplus into compute goldmines.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      TOO GREEN TO GO                             │
│                  Rails 7.1 Monolith + Hotwire                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐        │
│  │   Dashboard   │   │  API (JSON)  │   │ Demo Sim     │        │
│  │   (Hotwire)   │   │   /api/v1    │   │  Controls    │        │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘        │
│         │                   │                   │                │
│  ┌──────▼───────────────────▼───────────────────▼──────────┐    │
│  │              Controller Layer                            │    │
│  │  Dashboard · Workloads · ComputeNodes · GridStates       │    │
│  │  CurtailmentEvents · API::V1 · Demo::Simulation          │    │
│  └──────────────────────┬──────────────────────────────────┘    │
│                         │                                        │
│  ┌──────────────────────▼──────────────────────────────────┐    │
│  │              Service Layer (7 Services)                   │    │
│  │                                                           │    │
│  │  ┌─────────────────┐  ┌─────────────────┐                │    │
│  │  │  BrokerAgent    │  │  GridData        │                │    │
│  │  │  (Core Router)  │  │  (Susquehanna)   │                │    │
│  │  │  • route!       │  │  • ingest_zone!  │                │    │
│  │  │  • reroute!     │  │  • 11 zones      │                │    │
│  │  │  • scoring      │  │  • surplus det.  │                │    │
│  │  └─────────────────┘  └─────────────────┘                │    │
│  │                                                           │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐        │    │
│  │  │ Crusoe      │ │ Paid.ai     │ │ Stripe      │        │    │
│  │  │ Inference   │ │ Profitab.   │ │ B2B Billing │        │    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘        │    │
│  │                                                           │    │
│  │  ┌─────────────┐ ┌─────────────┐                         │    │
│  │  │ Solana      │ │ ElevenLabs  │                         │    │
│  │  │ B2C Payouts │ │ Audio Alert │                         │    │
│  │  └─────────────┘ └─────────────┘                         │    │
│  │                                                           │    │
│  │  ┌──────────────────────────────────┐                     │    │
│  │  │  IncidentAgent (incident.io)     │                     │    │
│  │  │  Adaptive state machine:         │                     │    │
│  │  │  MONITORING → ANOMALY_DETECTED   │                     │    │
│  │  │  → EVALUATING → ADAPTING         │                     │    │
│  │  │  → RESOLVED                      │                     │    │
│  │  └──────────────────────────────────┘                     │    │
│  └──────────────────────────────────────────────────────────┘    │
│                         │                                        │
│  ┌──────────────────────▼──────────────────────────────────┐    │
│  │              Model Layer (8 Models)                       │    │
│  │  Organization · ComputeNode · Workload · GridState       │    │
│  │  Transaction · RoutingDecision · CarbonReceipt           │    │
│  │  CurtailmentEvent                                         │    │
│  └──────────────────────┬──────────────────────────────────┘    │
│                         │                                        │
│  ┌──────────────────────▼──────────────────────────────────┐    │
│  │              SQLite3 (Development)                        │    │
│  │  8 tables · indexed · 33+ grid states per seed           │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Algorithm: Composite Routing Score

```
score = (0.6 × carbon_score) + (0.3 × price_score) + (0.1 × utilization_score)

where:
  carbon_score    = carbon_intensity / 500.0     (lower = better)
  price_score     = energy_price / 100.0         (lower = better)
  utilization_score = gpu_utilization             (lower = better)
```

**Reroute threshold**: Only reroute if new score is ≥25% better than current, max 5 reroutes per workload.

---

## Data Pipeline: Susquehanna "Data to Insight"

**11 Supported Zones**: FR, DE, ES, PT, NL, BE, IT, GB, US-CAL-CISO, US-NY-NYIS, US-TEX-ERCO

Each zone simulates realistic grid data:
- **Solar curve**: peak at noon (hours 10-16), varies by zone latitude
- **Wind pattern**: inverse correlation with solar, zone-specific capacity
- **Demand curve**: daily pattern peaking at hours 18-20
- **Carbon intensity**: derived from energy mix (EU average ~200 gCO₂/kWh)
- **Surplus detection**: when renewable generation > demand × 0.7
- **Curtailment detection**: when surplus exceeds installed capacity thresholds

---

## Sponsor Integration Map

| Sponsor | Integration | Service |
|---------|------------|---------|
| **Crusoe Energy** | Inference API for workload evaluation | `CrusoeInferenceService` |
| **Susquehanna (SIG)** | Data-to-Insight pipeline, grid analytics | `GridDataService` |
| **incident.io** | Adaptive agent with state machine | `IncidentAgentService` |
| **Stripe** | B2B billing, metered subscriptions | `StripeService` |
| **Solana** | B2C gamer payouts, carbon receipt NFTs | `SolanaService` |
| **ElevenLabs** | Audio alerts for curtailment events | `ElevenLabsService` |
| **Paid.ai** | Profitability tracking per routing decision | `PaidAiService` |
| **OpenShift AI** | Container orchestration (production deployment target) | Dockerfile included |
| **Miro AI** | Architecture diagram collaboration | This document |
| **Zed** | Development IDE | Development workflow |

---

## Database Schema

```
organizations (13 seeded)
├── compute_nodes (14 seeded, 10 datacenter + 4 gamer)
│   ├── workloads (assigned via routing)
│   │   ├── routing_decisions (audit trail)
│   │   ├── transactions (financial ledger)
│   │   └── carbon_receipts (on-chain proofs)
│   └── grid_zone → grid_states (time series)
└── curtailment_events (zone-level alerts)
```

---

## Business Model

### B2B (Datacenters & Enterprises)
- Metered billing via Stripe
- 15% platform fee on compute costs
- Guaranteed carbon reduction SLAs

### B2C (Gamers)
- Idle GPU monetization
- Solana payouts (instant, low-fee)
- Carbon receipt NFTs as proof of impact
- Revenue share: 85% to gamer

---

## API Endpoints

### Web Dashboard
| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Main dashboard with live grid |
| GET | `/dashboard/grid_map` | Full grid zone map |
| GET | `/dashboard/profitability` | Paid.ai profitability report |
| GET | `/workloads` | Workload management |
| POST | `/workloads/:id/route` | Trigger routing |
| POST | `/workloads/:id/reroute` | Force reroute |
| GET | `/compute_nodes` | Node fleet view |
| GET | `/grid_states/live_map` | Live energy map |
| GET | `/curtailment_events` | Alert center |

### REST API (JSON)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/workloads` | List workloads |
| POST | `/api/v1/workloads` | Submit workload |
| PUT | `/api/v1/workloads/:id/route` | Route workload |
| GET | `/api/v1/analytics/dashboard` | Dashboard stats |
| GET | `/api/v1/analytics/carbon_report` | Carbon report |
| GET | `/api/v1/analytics/zones` | Zone analytics |

### Demo Controls
| Method | Path | Description |
|--------|------|-------------|
| POST | `/demo/simulate/grid_cycle` | Simulate grid data refresh |
| POST | `/demo/simulate/create_workload` | Create random workload |
| POST | `/demo/simulate/trigger_reroute` | Trigger adaptive reroute |
| POST | `/demo/simulate/trigger_curtailment` | Simulate curtailment |
| POST | `/demo/simulate/complete_workloads` | Complete running workloads |

---

## Live Demo Flow

1. **Dashboard loads** — show live grid with 11 zones, color-coded by carbon intensity
2. **Click "Refresh Grid"** — simulate real-time energy data ingestion (Susquehanna)
3. **Create workload** — "Mistral fine-tune" routes to greenest available node
4. **Trigger curtailment** — France goes surplus → audio alert fires (ElevenLabs)
5. **Adaptive reroute** — incident agent detects carbon spike → moves workload
6. **Complete workloads** — Stripe bills B2B, Solana pays B2C gamers, carbon receipts minted
7. **Profitability report** — Paid.ai shows per-workload margins and carbon ROI

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Ruby 3.0.2, Rails 7.1.6 |
| Database | SQLite3 (dev), PostgreSQL (prod) |
| Frontend | Tailwind CSS (CDN), Hotwire/Turbo |
| Real-time | Turbo Streams, ActionCable |
| Background | Sidekiq + Redis (production) |
| Payments | Stripe API |
| Blockchain | Solana (Ed25519, Base58) |
| AI Inference | Crusoe Energy API |
| Voice | ElevenLabs Text-to-Speech |
| Monitoring | incident.io adaptive agent |
| Analytics | Paid.ai profitability |
| Deploy | Docker, OpenShift AI |

---

## Running Locally

```bash
# Install & setup
bundle install
bin/rails db:create db:migrate db:seed

# Start server
bin/rails server

# Visit http://localhost:3000
```

## Environment Variables (Production)

```
STRIPE_SECRET_KEY=sk_live_...
CRUSOE_API_KEY=...
SOLANA_PRIVATE_KEY=...
ELEVENLABS_API_KEY=...
INCIDENT_IO_API_KEY=...
PAID_AI_API_KEY=...
```

All services operate in **demo/mock mode** by default when keys are not configured.
