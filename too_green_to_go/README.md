# Too Green To Go

**Energy-Aware GPU Arbitrage Platform** — Route AI workloads to wherever clean energy is cheapest.

> *"The greenest compute wins."*

## What is this?

Too Green To Go monitors real-time energy grid data across 11 zones (EU + US), scores GPU nodes on a composite carbon-price-utilization metric, and automatically routes AI workloads to the optimal location. When the grid shifts, an adaptive agent reroutes workloads mid-execution to stay on green power.

## Quick Start

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
# Visit http://localhost:3000
```

## Key Features

- **Live Grid Dashboard** — 11 zones with real-time carbon intensity, renewable %, and energy prices
- **Broker Agent** — Composite scoring (60% carbon, 30% price, 10% utilization) with adaptive rerouting
- **B2B + B2C** — Enterprise billing (Stripe) + gamer GPU payouts (Solana)
- **Carbon Receipts** — On-chain proof of green compute
- **Curtailment Alerts** — Audio alerts (ElevenLabs) when clean energy is being wasted
- **Incident Agent** — State machine for anomaly detection and automated response

## Sponsor Integrations

Crusoe · Susquehanna · incident.io · Stripe · Solana · ElevenLabs · Paid.ai · OpenShift AI · Miro AI · Zed

## Docs

- [Architecture](docs/ARCHITECTURE.md) — System design, data flow, API reference
- [Pitch & Demo Script](docs/PITCH_AND_DEMO.md) — 2-minute YC pitch + live demo walkthrough

## License

MIT
