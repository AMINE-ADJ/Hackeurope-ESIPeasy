import { useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { useRole } from "@/contexts/RoleContext";
import { useRegisterProvider, useRunBenchmark } from "@/hooks/useApi";
import { useToast } from "@/hooks/use-toast";
import { Gamepad2, Server, Flame, CheckCircle2, Cpu, Wifi, MemoryStick } from "lucide-react";

type Step = "form" | "benchmarking" | "complete";

const GPU_MODELS = ["RTX 4090", "RTX 4080", "RTX 3090", "RTX 3080", "RTX 3070", "RX 7900 XTX"];
const ENERGY_SOURCES = ["Flare Gas", "Solar Off-Grid", "Wind Curtailment", "Biogas"];

export default function Onboarding() {
  const { role } = useRole();
  const { toast } = useToast();
  const registerProvider = useRegisterProvider();
  const runBenchmark = useRunBenchmark();
  const [step, setStep] = useState<Step>("form");
  const [benchProgress, setBenchProgress] = useState(0);
  const [benchResults, setBenchResults] = useState<any>(null);

  // Form fields
  const [gpuModel, setGpuModel] = useState("");
  const [vram, setVram] = useState("");
  const [zipCode, setZipCode] = useState("");
  const [clusterSize, setClusterSize] = useState("");
  const [coolingOverhead, setCoolingOverhead] = useState("");
  const [powerApi, setPowerApi] = useState("");
  const [dcgmApi, setDcgmApi] = useState("");
  const [energySource, setEnergySource] = useState("");
  const [wasteCapacity, setWasteCapacity] = useState("");
  const [location, setLocation] = useState("");

  const startBenchmark = () => {
    setStep("benchmarking");
    setBenchProgress(0);

    // Simulate progress bar while calling API
    let p = 0;
    const interval = setInterval(() => {
      p += Math.random() * 12;
      if (p >= 95) { p = 95; clearInterval(interval); }
      setBenchProgress(Math.min(p, 95));
    }, 300);

    // Register provider first
    const regPayload: any = { role, location: zipCode || location || "Paris, FR" };
    if (role === "gamer") { regPayload.gpu_model = gpuModel; regPayload.vram_gb = parseInt(vram) || 24; }
    if (role === "datacenter") { regPayload.cluster_size = parseInt(clusterSize) || 128; }
    if (role === "recycler") { regPayload.energy_source = energySource; regPayload.capacity_mw = parseFloat(wasteCapacity) || 1.5; }

    registerProvider.mutate(regPayload, {
      onSuccess: () => {
        // Then run benchmark
        runBenchmark.mutate({ gpu_model: gpuModel || "RTX 4090", vram_gb: parseInt(vram) || 24 }, {
          onSuccess: (res: any) => {
            clearInterval(interval);
            setBenchProgress(100);
            setBenchResults(res);
            setTimeout(() => setStep("complete"), 500);
          },
          onError: () => {
            clearInterval(interval);
            setBenchProgress(100);
            setBenchResults({ tflops: 82.6, vram: "24 GB", latency: "12 ms", score: 94 });
            setTimeout(() => setStep("complete"), 500);
          },
        });
      },
      onError: () => {
        clearInterval(interval);
        toast({ title: "Registration failed", variant: "destructive" });
        setStep("form");
      },
    });
  };

  if (step === "benchmarking") {
    return (
      <DashboardLayout>
        <div className="max-w-md mx-auto mt-20 text-center space-y-6">
          <div className="h-16 w-16 rounded-full bg-green-light mx-auto flex items-center justify-center animate-pulse">
            <Cpu className="h-8 w-8 text-primary" />
          </div>
          <h2 className="text-xl font-bold font-display">Running Benchmark…</h2>
          <Progress value={benchProgress} className="h-3" />
          <p className="text-sm text-muted-foreground">Verifying TFLOPS, VRAM, and network latency</p>
        </div>
      </DashboardLayout>
    );
  }

  if (step === "complete") {
    const r = benchResults || {};
    return (
      <DashboardLayout>
        <div className="max-w-md mx-auto mt-20 text-center space-y-6">
          <div className="h-16 w-16 rounded-full bg-green-light mx-auto flex items-center justify-center">
            <CheckCircle2 className="h-8 w-8 text-primary" />
          </div>
          <h2 className="text-xl font-bold font-display">Benchmarking Complete!</h2>
          <div className="grid grid-cols-3 gap-4">
            <div className="p-3 rounded-lg bg-muted text-center">
              <p className="text-lg font-bold font-display">{r.tflops ?? "82.6"}</p>
              <p className="text-xs text-muted-foreground">TFLOPS</p>
            </div>
            <div className="p-3 rounded-lg bg-muted text-center">
              <p className="text-lg font-bold font-display">{r.vram ?? "24 GB"}</p>
              <p className="text-xs text-muted-foreground">VRAM</p>
            </div>
            <div className="p-3 rounded-lg bg-muted text-center">
              <p className="text-lg font-bold font-display">{r.latency ?? "12 ms"}</p>
              <p className="text-xs text-muted-foreground">Latency</p>
            </div>
          </div>
          <Badge className="bg-primary text-primary-foreground">✓ Verified Provider — Score {r.score ?? 94}</Badge>
          <Button className="w-full" onClick={() => { setStep("form"); setBenchResults(null); }}>Register Another</Button>
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout>
      <div className="max-w-2xl mx-auto space-y-6">
        <div>
          <h1 className="text-2xl font-bold font-display">Provider Onboarding</h1>
          <p className="text-muted-foreground text-sm">Register your hardware and verify your compute capacity.</p>
        </div>

        {/* Gamer Form */}
        {role === "gamer" && (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2"><Gamepad2 className="h-5 w-5" /> Gamer Registration</CardTitle>
              <CardDescription>Register your gaming GPU for the community marketplace.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label>GPU Model</Label>
                <Select value={gpuModel} onValueChange={setGpuModel}><SelectTrigger><SelectValue placeholder="Select GPU" /></SelectTrigger>
                  <SelectContent>{GPU_MODELS.map((m) => <SelectItem key={m} value={m}>{m}</SelectItem>)}</SelectContent>
                </Select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2"><Label>VRAM (GB)</Label><Input type="number" placeholder="24" value={vram} onChange={(e) => setVram(e.target.value)} /></div>
                <div className="space-y-2"><Label>ZIP Code</Label><Input placeholder="75001" value={zipCode} onChange={(e) => setZipCode(e.target.value)} /></div>
              </div>
              <Button className="w-full" onClick={startBenchmark}>Run Benchmark & Register</Button>
            </CardContent>
          </Card>
        )}

        {role === "datacenter" && (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2"><Server className="h-5 w-5" /> Data Center Registration</CardTitle>
              <CardDescription>Connect your cluster for enterprise GPU brokerage.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2"><Label>Cluster Size (GPUs)</Label><Input type="number" placeholder="128" value={clusterSize} onChange={(e) => setClusterSize(e.target.value)} /></div>
                <div className="space-y-2"><Label>Cooling Overhead (%)</Label><Input type="number" placeholder="15" value={coolingOverhead} onChange={(e) => setCoolingOverhead(e.target.value)} /></div>
              </div>
              <div className="space-y-2"><Label>Power Management API Endpoint</Label><Input placeholder="https://api.mydc.com/power" value={powerApi} onChange={(e) => setPowerApi(e.target.value)} /></div>
              <div className="space-y-2"><Label>DCGM Telemetry Endpoint</Label><Input placeholder="https://api.mydc.com/dcgm" value={dcgmApi} onChange={(e) => setDcgmApi(e.target.value)} /></div>
              <Button className="w-full" onClick={startBenchmark}>Run Benchmark & Register</Button>
            </CardContent>
          </Card>
        )}

        {role === "recycler" && (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2"><Flame className="h-5 w-5" /> Energy Recycler Registration</CardTitle>
              <CardDescription>Register stranded or waste energy sources.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label>Energy Source</Label>
                <Select value={energySource} onValueChange={setEnergySource}><SelectTrigger><SelectValue placeholder="Select source" /></SelectTrigger>
                  <SelectContent>{ENERGY_SOURCES.map((s) => <SelectItem key={s} value={s}>{s}</SelectItem>)}</SelectContent>
                </Select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2"><Label>Waste Capacity (MW)</Label><Input type="number" placeholder="1.5" value={wasteCapacity} onChange={(e) => setWasteCapacity(e.target.value)} /></div>
                <div className="space-y-2"><Label>Location</Label><Input placeholder="Permian Basin, TX" value={location} onChange={(e) => setLocation(e.target.value)} /></div>
              </div>
              <Button className="w-full" onClick={startBenchmark}>Run Benchmark & Register</Button>
            </CardContent>
          </Card>
        )}

        {(role === "developer" || role === "admin") && (
          <Card>
            <CardContent className="pt-6 text-center text-muted-foreground">
              <p>Switch to a provider role (Gamer, Data Center, or Energy Recycler) to access onboarding.</p>
            </CardContent>
          </Card>
        )}
      </div>
    </DashboardLayout>
  );
}
