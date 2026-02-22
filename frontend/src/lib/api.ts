// API client for Too Green To Go backend
// All requests go through Vite proxy → Rails API at /api/v1/

const API_BASE = "/api/v1";

async function apiFetch<T>(path: string, options?: RequestInit): Promise<T> {
    const url = `${API_BASE}${path}`;
    const res = await fetch(url, {
        headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            ...options?.headers,
        },
        ...options,
    });

    if (!res.ok) {
        const errorBody = await res.text().catch(() => "Unknown error");
        throw new Error(`API ${res.status}: ${errorBody}`);
    }

    return res.json();
}

// ── Dashboard ──
export interface DashboardStats {
    co2_saved: string;
    co2_saved_raw: number;
    gpu_hours_brokered: string;
    energy_recovered: string;
    active_providers: number;
    active_jobs: number;
    avg_savings: string;
    total_workloads: number;
    completed_workloads: number;
    pending_workloads: number;
    total_nodes: number;
    green_nodes: number;
    available_nodes: number;
    healthy_nodes: number;
    total_revenue: number;
    reroute_rate: number;
    surplus_zones: string[];
    mig_slices_available: number;
}

export interface SurplusEvent {
    id: number;
    provider: string;
    region: string;
    drop: string;
    time: string;
    capacity: string;
    energy_price?: number;
    carbon_intensity?: number;
    renewable_pct?: number;
}

export interface EnergyProvider {
    name: string;
    region: string;
    spot_price?: number;
    spotPrice?: number;
    carbon_intensity?: number;
    carbonIntensity?: number;
    renewable_pct?: number;
    renewablePct?: number;
    status: "green" | "amber" | "red";
    surplus?: boolean;
    dominant_source?: string;
}

export interface Job {
    id: string;
    db_id: number;
    name: string;
    status: string;
    gpu: string;
    tier: string;
    green_score: number;
    greenScore?: number;
    progress: number;
    eta: string;
    workload_type?: string;
    priority?: string;
    green_only?: boolean;
    carbon_saved_grams?: number;
    carbon_expected_grams?: number;
    carbon_actual_grams?: number;
    carbon_reduction_pct?: number;
    renewable_pct?: number;
    node_name?: string;
    node_zone?: string;
    node_type?: string;
    created_at?: string;
    budget_max_eur?: number;
    estimated_cost?: number;
    hourly_rate?: number;
}

export interface GpuFleetItem {
    id: number;
    gpu: string;
    name: string;
    sm_util?: number;
    smUtil?: number;
    mem_util?: number;
    memUtil?: number;
    temp: number;
    power: number;
    mig: boolean;
    slices_used?: number;
    slicesUsed?: number;
    slices_total?: number;
    slicesTotal?: number;
    status: string;
    grid_zone?: string;
    gridZone?: string;
    health_status?: string;
    node_type?: string;
    organization?: string;
    underused?: boolean;
}

export interface DashboardData {
    stats: DashboardStats;
    surplus_events: SurplusEvent[];
    energy_providers: EnergyProvider[];
    jobs: Job[];
    gpu_fleet: GpuFleetItem[];
}

export function fetchDashboard(): Promise<DashboardData> {
    return apiFetch("/dashboard");
}

// ── Marketplace ──
export interface GpuListing {
    id: number;
    gpu: string;
    vram: string;
    vram_mb?: number;
    provider: string;
    provider_name?: string;
    green_score?: number;
    greenScore?: number;
    price: number;
    price_details?: {
        base_rate: number;
        tier: string;
        surplus_discount_pct: number;
        green_premium_pct: number;
        demand_multiplier: number;
    };
    location: string;
    grid_zone?: string;
    status: "available" | "busy" | "offline";
    node_type?: string;
    mig_enabled?: boolean;
    available_slices?: number;
    carbon_intensity?: number;
    renewable_pct?: number;
    health_status?: string;
    benchmark_score?: number;
}

export interface MarketplaceData {
    listings: GpuListing[];
    broker_priority: { rank: number; label: string; description: string }[];
    filters: {
        provider_types: string[];
        gpu_models: string[];
        grid_zones: string[];
    };
}

export function fetchMarketplace(): Promise<MarketplaceData> {
    return apiFetch("/marketplace");
}

export function deployOnNode(
    nodeId: number,
    opts: {
        name?: string;
        workload_type?: string;
        vram_mb?: number;
        green_only?: boolean;
        duration_hours?: number;
        docker_image?: string;
        budget?: number;
    }
): Promise<{ success: boolean; workload: { id: number; name: string; status: string; node?: string; tier?: string } }> {
    return apiFetch(`/marketplace/${nodeId}/deploy`, {
        method: "POST",
        body: JSON.stringify(opts),
    });
}

// ── Telemetry ──
export interface TelemetryItem {
    id: number;
    gpu: string;
    smUtil: number;
    memUtil: number;
    temp: number;
    power: number;
    mig: boolean;
    slicesUsed: number;
    slicesTotal: number;
    status?: string;
    gridZone?: string;
    nodeType?: string;
    underused?: boolean;
}

export interface UtilizationPoint {
    hour: string;
    sm: number;
    mem: number;
    power: number;
}

export interface TelemetryData {
    gpu_telemetry: TelemetryItem[];
    utilization_history: UtilizationPoint[];
}

export function fetchTelemetry(): Promise<TelemetryData> {
    return apiFetch("/telemetry");
}

// ── Heatmap ──
export interface HeatmapRegion {
    id: string;
    name: string;
    lat: number;
    lng: number;
    price: number;
    carbon: number;
    renewable_pct?: number;
    status: "green" | "amber" | "red";
    surplus?: boolean;
    dominant_source?: string;
    nodes_count?: number;
}

export interface HeatmapData {
    regions: HeatmapRegion[];
    energy_providers: EnergyProvider[];
    surplus_events: SurplusEvent[];
}

export function fetchHeatmap(): Promise<HeatmapData> {
    return apiFetch("/heatmap");
}

// ── Sustainability ──
export interface SustainabilityStats {
    co2Saved: string;
    revenue: number;
    savings: number;
    energyRecovered: string;
    wallet: number;
    carbonReceipts?: number;
    mintedReceipts?: number;
}

export interface PricingPoint {
    day: string;
    standard: number;
    recycled: number;
    gamer: number;
}

export interface TransactionItem {
    id: string;
    date: string;
    type: string;
    amount: string;
    job: string;
    status?: string;
}

export interface SustainabilityData {
    stats: SustainabilityStats;
    pricing_history: PricingPoint[];
    transactions: TransactionItem[];
}

export function fetchSustainability(): Promise<SustainabilityData> {
    return apiFetch("/sustainability");
}

// ── Admin ──
export interface WasteEvent {
    id: number;
    source: string;
    capacity: string;
    timeLeft: string;
    gpusActivated: number;
}

export interface ClusterOverview {
    gamer_nodes: number;
    datacenter_nodes: number;
    recycler_nodes: number;
    total_nodes: number;
    busy_nodes: number;
    idle_nodes: number;
    mig_enabled: number;
    green_compliant: number;
}

export interface AdminData {
    waste_events: WasteEvent[];
    cluster_overview: ClusterOverview;
    recent_overrides: { workload?: string; node?: string; reason?: string; time: string }[];
}

export function fetchAdmin(): Promise<AdminData> {
    return apiFetch("/admin");
}

export function declareWasteEvent(opts: {
    source?: string;
    capacity_mw?: number;
    grid_zone?: string;
    location?: string;
    duration_hours?: number;
}): Promise<{ success: boolean; event_id: number; gpus_activated: number; message: string }> {
    return apiFetch("/admin/declare_waste_event", {
        method: "POST",
        body: JSON.stringify(opts),
    });
}

// ── Workloads (Jobs) ──
export function fetchWorkloads(): Promise<Job[]> {
    // Use the dashboard endpoint which has better-formatted jobs
    return apiFetch<DashboardData>("/dashboard").then((d) => d.jobs);
}

export function submitWorkload(opts: {
    name?: string;
    workload_type: string;
    priority?: string;
    required_vram_mb?: number;
    green_only?: boolean;
    estimated_duration_hours?: number;
    docker_image?: string;
    budget_max_eur?: number;
    organization_id?: number;
}): Promise<{ id: number; name: string; status: string }> {
    return apiFetch("/workloads", {
        method: "POST",
        body: JSON.stringify(opts),
    });
}

export interface RouteResult {
    success: boolean;
    node?: { id: number; name: string; region: string; grid_zone: string; gpu_model: string };
    score?: number;
    tier?: string;
    carbon?: {
        expected_grams: number;
        actual_grams: number;
        saved_grams: number;
        reduction_pct: number;
        baseline_intensity: number;
        actual_intensity: number;
        renewable_pct: number;
        energy_kwh: number;
    };
    pricing?: {
        hourly_rate: number;
        estimated_total: number;
        currency: string;
    };
}

export function routeWorkload(id: number): Promise<RouteResult> {
    return apiFetch(`/workloads/${id}/route`, { method: "POST" });
}

// ── Onboarding ──
export function registerProvider(opts: {
    role: string;
    name?: string;
    email?: string;
    gpu_model?: string;
    vram_gb?: number;
    location?: string;
    zip_code?: string;
    energy_source?: string;
    capacity_mw?: number;
    cooling_type?: string;
    cooling_overhead?: number;
}): Promise<{ success: boolean; organization_id: number; node_id: number; message: string }> {
    return apiFetch("/onboarding/register", {
        method: "POST",
        body: JSON.stringify(opts),
    });
}

export function runBenchmark(nodeId: number): Promise<{
    success: boolean;
    results: { tflops: number; vram: string; latency: string; score: number; bandwidth: string };
}> {
    return apiFetch("/onboarding/benchmark", {
        method: "POST",
        body: JSON.stringify({ node_id: nodeId }),
    });
}

// ── Demo simulation ──
export function simulateGridCycle(): Promise<unknown> {
    return fetch("/demo/simulate_grid_cycle", { method: "POST" }).then((r) => r.json());
}

export function simulateWorkload(): Promise<unknown> {
    return fetch("/demo/simulate_workload", { method: "POST" }).then((r) => r.json());
}

export function simulateCompletion(): Promise<unknown> {
    return fetch("/demo/simulate_completion", { method: "POST" }).then((r) => r.json());
}
