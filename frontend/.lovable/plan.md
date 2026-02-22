
# Too Green to Go — Hackathon Demo Plan

## Overview
A polished, data-rich energy-aware GPU arbitrage platform demo with mock data, a role switcher, and stunning dashboards. Clean corporate design with green accent colors to reinforce the sustainability brand.

## Design System
- **Light theme** with white/slate backgrounds, professional typography
- **Green accent palette** (emerald/teal) for sustainability branding
- **Dark sidebar** for contrast, clean card-based layouts for content areas

---

## Pages & Features

### 1. Landing Page
- Hero section with tagline: "Turn Wasted Energy Into AI Power"
- Three value props for B2B, B2C, and Brokerage pillars
- Call-to-action buttons for Providers and Developers
- Key stats (mock): CO2 saved, GPU-hours brokered, energy recovered

### 2. Role Switcher (Top Bar)
- Dropdown to switch between: **Gamer**, **Data Center**, **Energy Recycler**, **AI Developer**, **Admin**
- Each role reveals a different dashboard and navigation — judges can explore all views instantly

### 3. Provider Onboarding (3 flows)
- **Gamer**: GPU model selector, VRAM input, ZIP code, mock benchmark results
- **Data Center**: Cluster size, cooling overhead, power management API fields
- **Energy Recycler**: Energy source type (Flare gas, Solar), waste capacity metrics
- Each flow ends with a mock "Benchmarking Complete" animation showing TFLOPS, VRAM, latency verified

### 4. Global Heatmap & Green Compliance Dashboard
- Interactive world/region map showing energy prices and carbon intensity by zone (mock data, using colored regions on a map visualization)
- Real-time indicators: green/amber/red zones based on carbon thresholds
- Energy provider data cards (EDF, Enedis, RTE) with mock spot prices and gCO2/kWh
- "Surplus Events" feed showing when prices drop and green windows open

### 5. GPU Marketplace & Smart Broker
- Filterable marketplace listing available GPUs with: provider type badge (Gamer/DC/Recycler), green score, price/GPU-hour, VRAM, location
- Job submission form: Docker image, VRAM requirements, budget slider, Green Tier toggle (Standard vs 100% Recycled)
- Priority matching visualization showing the 3-tier routing logic (Recycler → Surplus DC → Green Gamer)
- Async job queue view for non-urgent tasks waiting for surplus events

### 6. GPU Slicing & Telemetry (Data Center View)
- Live GPU utilization dashboard with mock streaming multiprocessor and memory charts (using Recharts)
- Visual representation of MIG partitioning: full GPU bar showing used vs. available slices
- Auto-detected underutilized GPUs (<70%) highlighted with "Sub-lease Available" badges
- One-click "List on Marketplace" action for fractional slices

### 7. Sustainability & Financials Dashboard
- **For Developers**: CO2 offset counter, cost savings vs. traditional cloud, job history with green scores
- **For Providers**: Revenue earned, wasted energy recovered (kWh), GPU utilization improvements
- Dynamic pricing chart showing price fluctuations based on green-ness and demand
- Mock wallet balance and transaction history

### 8. Admin — Crusoe Override Panel
- "Declare Waste Event" button with capacity input (e.g., "1MW excess flare gas")
- Active waste events feed with countdown timers
- Global cluster overview with provider counts by type

### 9. Sidebar Navigation
- Role-aware navigation: shows different menu items per role
- Sections: Dashboard, Marketplace, My GPUs, Jobs, Sustainability, Settings
- Admin gets additional: Override Panel, Global Heatmap, Provider Management

---

## Technical Approach
- All data is **mock/hardcoded** for demo speed — realistic-looking JSON fixtures
- **Recharts** for all charts (utilization, pricing, CO2 tracking)
- **Role switcher** stored in React context — instantly swaps the entire UI
- Sidebar layout using shadcn sidebar component
- Responsive but optimized for desktop demo presentation
