import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Slider } from "@/components/ui/slider";
import { Switch } from "@/components/ui/switch";
import { Progress } from "@/components/ui/progress";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useJobs, useSubmitWorkload, useRouteWorkload } from "@/hooks/useApi";
import { LoadingState, ErrorState } from "@/components/LoadingState";
import type { RouteResult } from "@/lib/api";
import {
  BriefcaseBusiness, Plus, Clock, CheckCircle2, Loader2, Pause,
  Leaf, Zap, ArrowRight, TrendingDown, Server, X
} from "lucide-react";
import { useState } from "react";
import { useToast } from "@/hooks/use-toast";

const statusIcons: Record<string, React.ElementType> = { running: Loader2, queued: Clock, completed: CheckCircle2, waiting: Pause, pending: Clock, paused: Pause };
const statusColors: Record<string, string> = { running: "bg-primary", queued: "bg-amber", completed: "bg-muted-foreground", waiting: "bg-blue-500", pending: "bg-amber", paused: "bg-blue-500" };

type SubmitStep = "idle" | "form" | "submitting" | "routing" | "result";

export default function Jobs() {
  const [step, setStep] = useState<SubmitStep>("idle");
  const [budget, setBudget] = useState([35]);
  const [dockerImage, setDockerImage] = useState("ghcr.io/mistral-ai/mistral-7b:inference");
  const [vram, setVram] = useState("40");
  const [greenOnly, setGreenOnly] = useState(true);
  const [jobName, setJobName] = useState("Mistral-7B Inference");
  const [workloadType, setWorkloadType] = useState("inference");
  const [duration, setDuration] = useState("2");
  const [routeResult, setRouteResult] = useState<RouteResult | null>(null);

  const { data: jobs, isLoading, error, refetch } = useJobs();
  const submitMutation = useSubmitWorkload();
  const routeMutation = useRouteWorkload();
  const { toast } = useToast();

  const resetForm = () => {
    setStep("idle");
    setRouteResult(null);
    setJobName("Mistral-7B Inference");
    setDockerImage("ghcr.io/mistral-ai/mistral-7b:inference");
    setVram("40");
    setBudget([35]);
    setGreenOnly(true);
    setWorkloadType("inference");
    setDuration("2");
  };

  const handleSubmit = () => {
    setStep("submitting");
    submitMutation.mutate(
      {
        name: jobName || `Job ${Date.now()}`,
        workload_type: workloadType,
        priority: greenOnly ? "async" : "normal",
        required_vram_mb: parseInt(vram || "24") * 1024,
        green_only: greenOnly,
        estimated_duration_hours: parseFloat(duration) || 1,
        docker_image: dockerImage || "ghcr.io/default/workload:latest",
        budget_max_eur: budget[0] / 10,
      },
      {
        onSuccess: (res) => {
          setStep("routing");
          toast({ title: "Job submitted!", description: `${res.name || "Workload"} created. Routing to greenest node...` });
          // Auto-route the workload
          routeMutation.mutate(res.id, {
            onSuccess: (routeRes) => {
              setRouteResult(routeRes);
              setStep("result");
              if (routeRes.success) {
                toast({
                  title: "Routed to energy recycler!",
                  description: `${routeRes.node?.name} — ${routeRes.carbon?.saved_grams?.toFixed(0)}g CO₂ saved`
                });
              }
            },
            onError: () => {
              setStep("form");
              toast({ title: "Routing failed", description: "No eligible green nodes found.", variant: "destructive" });
            },
          });
        },
        onError: () => {
          setStep("form");
          toast({ title: "Error", description: "Failed to submit job.", variant: "destructive" });
        },
      }
    );
  };

  if (isLoading) return <DashboardLayout><LoadingState /></DashboardLayout>;
  if (error) return <DashboardLayout><ErrorState onRetry={() => refetch()} /></DashboardLayout>;

  const jobList = jobs || [];

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold font-display">AI Workloads</h1>
            <p className="text-muted-foreground text-sm">Submit workloads → auto-routed to the greenest GPU available.</p>
          </div>
          {step === "idle" && (
            <Button onClick={() => setStep("form")}>
              <Plus className="h-4 w-4 mr-1" /> New Workload
            </Button>
          )}
        </div>

        {/* ── STEP 1: Submission Form ── */}
        {(step === "form" || step === "submitting") && (
          <Card className="border-primary/30 bg-card/50">
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between">
                <CardTitle className="text-lg flex items-center gap-2">
                  <Zap className="h-5 w-5 text-primary" /> Place AI Workload
                </CardTitle>
                <Button variant="ghost" size="icon" onClick={resetForm}><X className="h-4 w-4" /></Button>
              </div>
              <p className="text-sm text-muted-foreground">
                Configure your workload. The Smart Broker will find the greenest, cheapest GPU node automatically.
              </p>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid sm:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Job Name</Label>
                  <Input placeholder="Mistral-7B Inference" value={jobName} onChange={(e) => setJobName(e.target.value)} />
                </div>
                <div className="space-y-2">
                  <Label>Workload Type</Label>
                  <Select value={workloadType} onValueChange={setWorkloadType}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="inference">Inference</SelectItem>
                      <SelectItem value="fine_tune">Fine-tuning</SelectItem>
                      <SelectItem value="training">Training</SelectItem>
                      <SelectItem value="embedding">Embedding</SelectItem>
                      <SelectItem value="batch_inference">Batch Inference</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="grid sm:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Docker Image</Label>
                  <Input placeholder="myorg/llm-trainer:latest" value={dockerImage} onChange={(e) => setDockerImage(e.target.value)} />
                </div>
                <div className="space-y-2">
                  <Label>VRAM Required</Label>
                  <Select value={vram} onValueChange={setVram}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="10">10 GB</SelectItem>
                      <SelectItem value="24">24 GB</SelectItem>
                      <SelectItem value="40">40 GB</SelectItem>
                      <SelectItem value="80">80 GB</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="grid sm:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Estimated Duration: {duration}h</Label>
                  <Select value={duration} onValueChange={setDuration}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="0.5">30 min</SelectItem>
                      <SelectItem value="1">1 hour</SelectItem>
                      <SelectItem value="2">2 hours</SelectItem>
                      <SelectItem value="4">4 hours</SelectItem>
                      <SelectItem value="8">8 hours</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>Budget: €{(budget[0] / 10).toFixed(1)}/hr</Label>
                  <Slider value={budget} onValueChange={setBudget} max={100} step={1} />
                </div>
              </div>
              <div className="flex items-center gap-3 p-3 rounded-lg border border-primary/20 bg-primary/5">
                <Switch id="green-tier" checked={greenOnly} onCheckedChange={setGreenOnly} />
                <div>
                  <Label htmlFor="green-tier" className="font-medium">♻ 100% Green Energy Only</Label>
                  <p className="text-xs text-muted-foreground">Route exclusively to Tier 1 energy recyclers powered by waste heat</p>
                </div>
              </div>
              <Button className="w-full" size="lg" onClick={handleSubmit} disabled={step === "submitting"}>
                {step === "submitting" ? (
                  <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Submitting...</>
                ) : (
                  <><ArrowRight className="h-4 w-4 mr-2" /> Submit to Smart Broker</>
                )}
              </Button>
            </CardContent>
          </Card>
        )}

        {/* ── STEP 2: Routing in progress ── */}
        {step === "routing" && (
          <Card className="border-primary/30">
            <CardContent className="py-10 text-center space-y-4">
              <Loader2 className="h-10 w-10 text-primary animate-spin mx-auto" />
              <div>
                <h3 className="font-display font-bold text-lg">Smart Broker Routing...</h3>
                <p className="text-sm text-muted-foreground">
                  Evaluating GPU nodes across 11 grid zones • Scoring carbon + price + utilization
                </p>
              </div>
              <div className="max-w-md mx-auto space-y-1 text-xs text-muted-foreground">
                <p>→ Filtering by Green Compliance Engine...</p>
                <p>→ Checking Tier 1 Energy Recyclers (always-green)...</p>
                <p>→ Scoring candidates: 60% carbon + 30% price + 10% utilization...</p>
              </div>
            </CardContent>
          </Card>
        )}

        {/* ── STEP 3: Routing Result with Carbon Breakdown ── */}
        {step === "result" && routeResult && (
          <Card className="border-primary/30 bg-gradient-to-br from-primary/5 via-transparent to-transparent">
            <CardHeader className="pb-2">
              <div className="flex items-center justify-between">
                <CardTitle className="text-lg flex items-center gap-2">
                  <CheckCircle2 className="h-5 w-5 text-primary" /> Workload Routed Successfully
                </CardTitle>
                <Button variant="outline" size="sm" onClick={resetForm}>Close</Button>
              </div>
            </CardHeader>
            <CardContent className="space-y-5">
              {/* Node Assignment */}
              <div className="flex items-start gap-4 p-4 rounded-lg border bg-card">
                <div className="h-10 w-10 rounded-lg bg-primary/20 flex items-center justify-center">
                  <Server className="h-5 w-5 text-primary" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-display font-bold">{routeResult.node?.name || "Unknown"}</span>
                    <Badge className="bg-primary/20 text-primary border-0">♻ {routeResult.tier === "tier_1_recycler" ? "Energy Recycler" : routeResult.tier === "tier_2_b2b_surplus" ? "Surplus DC" : "Green"}</Badge>
                    <Badge variant="outline">{routeResult.node?.gpu_model}</Badge>
                  </div>
                  <p className="text-sm text-muted-foreground mt-0.5">
                    Zone: {routeResult.node?.grid_zone} • Region: {routeResult.node?.region} • Score: {routeResult.score?.toFixed(4)}
                  </p>
                </div>
                {routeResult.pricing && (
                  <div className="text-right">
                    <p className="font-bold text-primary">€{routeResult.pricing.hourly_rate}/hr</p>
                    <p className="text-xs text-muted-foreground">Est. €{routeResult.pricing.estimated_total} total</p>
                  </div>
                )}
              </div>

              {/* Carbon Breakdown */}
              {routeResult.carbon && (
                <div className="space-y-3">
                  <h4 className="font-display font-semibold flex items-center gap-2">
                    <Leaf className="h-4 w-4 text-primary" /> Carbon Impact Breakdown
                  </h4>
                  <div className="grid grid-cols-3 gap-3">
                    <div className="p-3 rounded-lg border bg-red-500/5 border-red-500/20 text-center">
                      <p className="text-xs text-muted-foreground mb-1">Expected (Dirty Grid)</p>
                      <p className="text-xl font-bold text-red-400">{routeResult.carbon.expected_grams.toFixed(0)}g</p>
                      <p className="text-xs text-muted-foreground">{routeResult.carbon.baseline_intensity} gCO₂/kWh</p>
                    </div>
                    <div className="p-3 rounded-lg border bg-primary/5 border-primary/20 text-center">
                      <p className="text-xs text-muted-foreground mb-1">Actual (Green Node)</p>
                      <p className="text-xl font-bold text-primary">{routeResult.carbon.actual_grams.toFixed(0)}g</p>
                      <p className="text-xs text-muted-foreground">{routeResult.carbon.actual_intensity} gCO₂/kWh</p>
                    </div>
                    <div className="p-3 rounded-lg border bg-emerald-500/10 border-emerald-500/30 text-center">
                      <p className="text-xs text-muted-foreground mb-1">Carbon Saved</p>
                      <p className="text-xl font-bold text-emerald-400">{routeResult.carbon.saved_grams.toFixed(0)}g</p>
                      <div className="flex items-center justify-center gap-1 mt-0.5">
                        <TrendingDown className="h-3 w-3 text-emerald-400" />
                        <span className="text-xs font-semibold text-emerald-400">
                          {routeResult.carbon.reduction_pct.toFixed(0)}% reduction
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Visual bar comparing expected vs actual */}
                  <div className="space-y-2 pt-1">
                    <div className="space-y-1">
                      <div className="flex justify-between text-xs">
                        <span className="text-muted-foreground">Dirty grid baseline</span>
                        <span className="text-red-400">{routeResult.carbon.expected_grams.toFixed(0)}g CO₂</span>
                      </div>
                      <div className="h-3 rounded-full bg-red-500/20 overflow-hidden">
                        <div className="h-full rounded-full bg-red-500/60" style={{ width: "100%" }} />
                      </div>
                    </div>
                    <div className="space-y-1">
                      <div className="flex justify-between text-xs">
                        <span className="text-muted-foreground">ESIPeasy green route</span>
                        <span className="text-primary">{routeResult.carbon.actual_grams.toFixed(0)}g CO₂</span>
                      </div>
                      <div className="h-3 rounded-full bg-primary/20 overflow-hidden">
                        <div
                          className="h-full rounded-full bg-primary"
                          style={{
                            width: `${routeResult.carbon.expected_grams > 0
                              ? Math.max((routeResult.carbon.actual_grams / routeResult.carbon.expected_grams) * 100, 2)
                              : 0}%`
                          }}
                        />
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-4 text-xs text-muted-foreground pt-1">
                    <span>⚡ {routeResult.carbon.energy_kwh.toFixed(3)} kWh consumed</span>
                    <span>🌿 {routeResult.carbon.renewable_pct}% renewable</span>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        )}

        {/* ── Job List with Carbon Metrics ── */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <BriefcaseBusiness className="h-5 w-5 text-primary" /> All Workloads
              <Badge variant="secondary" className="ml-auto">{jobList.length}</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {jobList.length === 0 && (
              <p className="text-sm text-muted-foreground text-center py-8">No workloads yet. Submit one above!</p>
            )}
            {jobList.map((j) => {
              const Icon = statusIcons[j.status] || Clock;
              const color = statusColors[j.status] || "bg-muted";
              const hasCarbonData = (j.carbon_expected_grams ?? 0) > 0;
              return (
                <div key={j.id} className="p-3 rounded-lg border space-y-2">
                  <div className="flex items-center gap-3">
                    <div className={`h-8 w-8 rounded-full flex items-center justify-center ${color}/20`}>
                      <Icon className={`h-4 w-4 ${j.status === "running" ? "animate-spin text-primary" : "text-muted-foreground"}`} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-medium text-sm truncate">{j.name}</span>
                        <Badge variant="outline" className="text-xs">{j.status}</Badge>
                        {j.tier === "Recycled" && <Badge className="bg-primary/20 text-primary text-xs border-0">♻ Recycler</Badge>}
                        {j.tier === "Surplus" && <Badge className="bg-blue-500/20 text-blue-400 text-xs border-0">⚡ Surplus</Badge>}
                        {j.tier === "Green" && <Badge className="bg-emerald-500/20 text-emerald-400 text-xs border-0">🌿 Green</Badge>}
                      </div>
                      <p className="text-xs text-muted-foreground">
                        {j.id} • {j.gpu !== "—" ? j.gpu : "Pending"} • {j.node_name || "Unassigned"} • {j.node_zone || ""} • ETA: {j.eta}
                      </p>
                    </div>
                    <div className="w-24 shrink-0">
                      <Progress value={j.progress} className="h-2" />
                      <p className="text-xs text-right text-muted-foreground mt-0.5">{j.progress}%</p>
                    </div>
                  </div>
                  {/* Carbon row */}
                  {hasCarbonData && (
                    <div className="flex items-center gap-3 pl-11 text-xs">
                      <span className="text-red-400/70">Expected: {j.carbon_expected_grams?.toFixed(0)}g</span>
                      <span className="text-primary">Actual: {j.carbon_actual_grams?.toFixed(0)}g</span>
                      <span className="text-emerald-400 font-semibold flex items-center gap-1">
                        <TrendingDown className="h-3 w-3" />
                        Saved: {j.carbon_saved_grams?.toFixed(0)}g ({j.carbon_reduction_pct?.toFixed(0)}%)
                      </span>
                      {j.renewable_pct !== undefined && j.renewable_pct > 0 && (
                        <span className="text-muted-foreground">🌿 {j.renewable_pct}% renewable</span>
                      )}
                      {j.hourly_rate !== undefined && j.hourly_rate > 0 && (
                        <span className="text-muted-foreground ml-auto">€{j.hourly_rate}/hr</span>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}
