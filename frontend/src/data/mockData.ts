export const STATS = {
  co2Saved: "12,450",
  gpuHoursBrokered: "1.2M",
  energyRecovered: "890 MWh",
  activeProviders: "3,240",
  activeJobs: "567",
  avgSavings: "43%",
};

export const ENERGY_PROVIDERS = [
  { name: "EDF", region: "France", spotPrice: 42.3, carbonIntensity: 58, status: "green" as const },
  { name: "RTE", region: "France", spotPrice: 38.7, carbonIntensity: 45, status: "green" as const },
  { name: "Enedis", region: "France", spotPrice: 51.2, carbonIntensity: 112, status: "amber" as const },
  { name: "E.ON", region: "Germany", spotPrice: 67.8, carbonIntensity: 320, status: "red" as const },
  { name: "Vattenfall", region: "Sweden", spotPrice: 22.1, carbonIntensity: 12, status: "green" as const },
  { name: "Iberdrola", region: "Spain", spotPrice: 35.4, carbonIntensity: 89, status: "green" as const },
];

export const SURPLUS_EVENTS = [
  { id: 1, provider: "EDF", region: "Île-de-France", drop: "-32%", time: "2 min ago", capacity: "450 MW" },
  { id: 2, provider: "Vattenfall", region: "Stockholm", drop: "-48%", time: "8 min ago", capacity: "1.2 GW" },
  { id: 3, provider: "RTE", region: "Provence", drop: "-21%", time: "15 min ago", capacity: "200 MW" },
];

export const GPU_LISTINGS = [
  { id: 1, gpu: "RTX 4090", vram: "24GB", provider: "Gamer", greenScore: 92, price: 0.45, location: "Paris, FR", status: "available" as const },
  { id: 2, gpu: "A100 (Slice)", vram: "20GB", provider: "Data Center", greenScore: 78, price: 0.82, location: "Frankfurt, DE", status: "available" as const },
  { id: 3, gpu: "H100", vram: "80GB", provider: "Recycler", greenScore: 100, price: 1.20, location: "Texas, US", status: "busy" as const },
  { id: 4, gpu: "RTX 3080", vram: "10GB", provider: "Gamer", greenScore: 65, price: 0.22, location: "Stockholm, SE", status: "available" as const },
  { id: 5, gpu: "A100", vram: "40GB", provider: "Data Center", greenScore: 88, price: 1.05, location: "Lyon, FR", status: "available" as const },
  { id: 6, gpu: "RTX 4080", vram: "16GB", provider: "Gamer", greenScore: 45, price: 0.35, location: "Berlin, DE", status: "offline" as const },
  { id: 7, gpu: "H100 (Slice)", vram: "40GB", provider: "Recycler", greenScore: 100, price: 0.95, location: "North Dakota, US", status: "available" as const },
  { id: 8, gpu: "A10G", vram: "24GB", provider: "Data Center", greenScore: 71, price: 0.55, location: "Madrid, ES", status: "available" as const },
];

export const GPU_TELEMETRY = [
  { id: 1, gpu: "A100-0", smUtil: 42, memUtil: 55, temp: 62, power: 210, mig: true, slicesUsed: 3, slicesTotal: 7 },
  { id: 2, gpu: "A100-1", smUtil: 88, memUtil: 91, temp: 74, power: 290, mig: false, slicesUsed: 7, slicesTotal: 7 },
  { id: 3, gpu: "A100-2", smUtil: 31, memUtil: 28, temp: 48, power: 150, mig: true, slicesUsed: 2, slicesTotal: 7 },
  { id: 4, gpu: "H100-0", smUtil: 67, memUtil: 72, temp: 68, power: 350, mig: true, slicesUsed: 5, slicesTotal: 7 },
  { id: 5, gpu: "H100-1", smUtil: 95, memUtil: 89, temp: 78, power: 420, mig: false, slicesUsed: 7, slicesTotal: 7 },
  { id: 6, gpu: "A100-3", smUtil: 15, memUtil: 12, temp: 41, power: 100, mig: true, slicesUsed: 1, slicesTotal: 7 },
];

export const JOBS = [
  { id: "JOB-001", name: "LLM Fine-tuning", status: "running" as const, gpu: "H100", tier: "Recycled", greenScore: 100, progress: 67, eta: "2h 15m" },
  { id: "JOB-002", name: "Image Generation", status: "queued" as const, gpu: "A100", tier: "Standard", greenScore: 78, progress: 0, eta: "Waiting" },
  { id: "JOB-003", name: "Speech-to-Text", status: "running" as const, gpu: "RTX 4090", tier: "Standard", greenScore: 92, progress: 34, eta: "45m" },
  { id: "JOB-004", name: "Video Encoding", status: "completed" as const, gpu: "A100 Slice", tier: "Recycled", greenScore: 100, progress: 100, eta: "Done" },
  { id: "JOB-005", name: "RAG Pipeline", status: "waiting" as const, gpu: "—", tier: "Async", greenScore: 0, progress: 0, eta: "Next surplus" },
];

export const UTILIZATION_HISTORY = Array.from({ length: 24 }, (_, i) => ({
  hour: `${i}:00`,
  sm: Math.floor(40 + Math.random() * 50),
  mem: Math.floor(30 + Math.random() * 60),
  power: Math.floor(150 + Math.random() * 250),
}));

export const PRICING_HISTORY = Array.from({ length: 30 }, (_, i) => ({
  day: `Feb ${i + 1}`,
  standard: +(0.8 + Math.random() * 0.4).toFixed(2),
  recycled: +(1.0 + Math.random() * 0.5).toFixed(2),
  gamer: +(0.2 + Math.random() * 0.3).toFixed(2),
}));

export const TRANSACTIONS = [
  { id: "TX-001", date: "Feb 21", type: "Earning", amount: "+$124.50", job: "LLM Fine-tuning" },
  { id: "TX-002", date: "Feb 20", type: "Payout", amount: "-$500.00", job: "Withdrawal" },
  { id: "TX-003", date: "Feb 20", type: "Earning", amount: "+$89.20", job: "Image Generation" },
  { id: "TX-004", date: "Feb 19", type: "Fee", amount: "-$12.40", job: "Platform fee" },
  { id: "TX-005", date: "Feb 18", type: "Earning", amount: "+$234.10", job: "Video Encoding" },
];

export const WASTE_EVENTS = [
  { id: 1, source: "Flare Gas — Permian Basin", capacity: "1.2 MW", timeLeft: "4h 32m", gpusActivated: 48 },
  { id: 2, source: "Solar Overcapacity — Mojave", capacity: "800 kW", timeLeft: "2h 10m", gpusActivated: 32 },
];

export const HEATMAP_REGIONS = [
  { id: "france", name: "France", lat: 46.6, lng: 2.2, price: 42.3, carbon: 58, status: "green" as const },
  { id: "germany", name: "Germany", lat: 51.2, lng: 10.4, price: 67.8, carbon: 320, status: "red" as const },
  { id: "sweden", name: "Sweden", lat: 62.0, lng: 15.0, price: 22.1, carbon: 12, status: "green" as const },
  { id: "spain", name: "Spain", lat: 40.5, lng: -3.7, price: 35.4, carbon: 89, status: "green" as const },
  { id: "uk", name: "United Kingdom", lat: 55.4, lng: -3.4, price: 55.0, carbon: 195, status: "amber" as const },
  { id: "poland", name: "Poland", lat: 52.0, lng: 20.0, price: 72.1, carbon: 650, status: "red" as const },
  { id: "norway", name: "Norway", lat: 60.5, lng: 8.5, price: 18.5, carbon: 8, status: "green" as const },
  { id: "italy", name: "Italy", lat: 42.5, lng: 12.5, price: 48.9, carbon: 210, status: "amber" as const },
  { id: "texas", name: "Texas, US", lat: 31.0, lng: -99.0, price: 28.0, carbon: 410, status: "amber" as const },
  { id: "california", name: "California, US", lat: 36.8, lng: -119.4, price: 45.0, carbon: 180, status: "amber" as const },
];
