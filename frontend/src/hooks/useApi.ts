import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
    fetchDashboard,
    fetchMarketplace,
    fetchTelemetry,
    fetchHeatmap,
    fetchSustainability,
    fetchAdmin,
    fetchWorkloads,
    deployOnNode,
    declareWasteEvent,
    submitWorkload,
    routeWorkload,
    registerProvider,
    runBenchmark,
    simulateGridCycle,
    simulateWorkload,
    simulateCompletion,
} from "@/lib/api";
import type {
    DashboardData,
    MarketplaceData,
    TelemetryData,
    HeatmapData,
    SustainabilityData,
    AdminData,
    Job,
} from "@/lib/api";

// ── Dashboard ──
export function useDashboard() {
    return useQuery<DashboardData>({
        queryKey: ["dashboard"],
        queryFn: fetchDashboard,
        refetchInterval: 10_000, // Refresh every 10s for live feel
        staleTime: 5_000,
    });
}

// ── Marketplace ──
export function useMarketplace() {
    return useQuery<MarketplaceData>({
        queryKey: ["marketplace"],
        queryFn: fetchMarketplace,
        refetchInterval: 15_000,
        staleTime: 8_000,
    });
}

export function useDeployOnNode() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: ({ nodeId, ...opts }: { nodeId: number } & Parameters<typeof deployOnNode>[1]) =>
            deployOnNode(nodeId, opts),
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: ["marketplace"] });
            qc.invalidateQueries({ queryKey: ["dashboard"] });
        },
    });
}

// ── Jobs / Workloads ──
export function useJobs() {
    return useQuery<Job[]>({
        queryKey: ["jobs"],
        queryFn: fetchWorkloads,
        refetchInterval: 8_000,
        staleTime: 4_000,
    });
}

export function useSubmitWorkload() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: submitWorkload,
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: ["jobs"] });
            qc.invalidateQueries({ queryKey: ["dashboard"] });
        },
    });
}

export function useRouteWorkload() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: routeWorkload,
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: ["jobs"] });
            qc.invalidateQueries({ queryKey: ["dashboard"] });
        },
    });
}

// ── Telemetry ──
export function useTelemetry() {
    return useQuery<TelemetryData>({
        queryKey: ["telemetry"],
        queryFn: fetchTelemetry,
        refetchInterval: 10_000,
        staleTime: 5_000,
    });
}

// ── Heatmap ──
export function useHeatmap() {
    return useQuery<HeatmapData>({
        queryKey: ["heatmap"],
        queryFn: fetchHeatmap,
        refetchInterval: 12_000,
        staleTime: 6_000,
    });
}

// ── Sustainability ──
export function useSustainability() {
    return useQuery<SustainabilityData>({
        queryKey: ["sustainability"],
        queryFn: fetchSustainability,
        refetchInterval: 20_000,
        staleTime: 10_000,
    });
}

// ── Admin ──
export function useAdmin() {
    return useQuery<AdminData>({
        queryKey: ["admin"],
        queryFn: fetchAdmin,
        refetchInterval: 10_000,
        staleTime: 5_000,
    });
}

export function useDeclareWasteEvent() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: declareWasteEvent,
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: ["admin"] });
            qc.invalidateQueries({ queryKey: ["dashboard"] });
            qc.invalidateQueries({ queryKey: ["heatmap"] });
        },
    });
}

// ── Onboarding ──
export function useRegisterProvider() {
    return useMutation({
        mutationFn: registerProvider,
    });
}

export function useRunBenchmark() {
    return useMutation({
        mutationFn: runBenchmark,
    });
}

// ── Demo Simulation ──
export function useSimulateGridCycle() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: simulateGridCycle,
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: ["dashboard"] });
            qc.invalidateQueries({ queryKey: ["heatmap"] });
            qc.invalidateQueries({ queryKey: ["telemetry"] });
        },
    });
}

export function useSimulateWorkload() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: simulateWorkload,
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: ["dashboard"] });
            qc.invalidateQueries({ queryKey: ["jobs"] });
        },
    });
}

export function useSimulateCompletion() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: simulateCompletion,
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: ["dashboard"] });
            qc.invalidateQueries({ queryKey: ["jobs"] });
            qc.invalidateQueries({ queryKey: ["sustainability"] });
        },
    });
}
