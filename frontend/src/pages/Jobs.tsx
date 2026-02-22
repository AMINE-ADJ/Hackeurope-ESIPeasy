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
import { BriefcaseBusiness, Plus, Clock, CheckCircle2, Loader2, Pause } from "lucide-react";
import { useState } from "react";
import { useToast } from "@/hooks/use-toast";

const statusIcons: Record<string, React.ElementType> = { running: Loader2, queued: Clock, completed: CheckCircle2, waiting: Pause, pending: Clock, paused: Pause };
const statusColors: Record<string, string> = { running: "bg-primary", queued: "bg-amber", completed: "bg-muted-foreground", waiting: "bg-blue-500", pending: "bg-amber", paused: "bg-blue-500" };

export default function Jobs() {
  const [showSubmit, setShowSubmit] = useState(false);
  const [budget, setBudget] = useState([50]);
  const [dockerImage, setDockerImage] = useState("");
  const [vram, setVram] = useState("");
  const [greenOnly, setGreenOnly] = useState(false);
  const [jobName, setJobName] = useState("");

  const { data: jobs, isLoading, error, refetch } = useJobs();
  const submitMutation = useSubmitWorkload();
  const routeMutation = useRouteWorkload();
  const { toast } = useToast();

  const handleSubmit = () => {
    submitMutation.mutate(
      {
        name: jobName || `Job ${Date.now()}`,
        workload_type: "inference",
        priority: greenOnly ? "async" : "normal",
        required_vram_mb: parseInt(vram || "24") * 1024,
        green_only: greenOnly,
        estimated_duration_hours: 1,
        docker_image: dockerImage || "ghcr.io/default/workload:latest",
        budget_max_eur: budget[0] / 10,
      },
      {
        onSuccess: (res) => {
          toast({ title: "Job submitted!", description: `${res.name || "Workload"} created. Routing...` });
          // Auto-route the workload
          routeMutation.mutate(res.id);
          setShowSubmit(false);
          setJobName("");
          setDockerImage("");
        },
        onError: () => {
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
            <h1 className="text-2xl font-bold font-display">Jobs</h1>
            <p className="text-muted-foreground text-sm">Submit and monitor your AI workloads.</p>
          </div>
          <Button onClick={() => setShowSubmit(!showSubmit)}>
            <Plus className="h-4 w-4 mr-1" /> Submit Job
          </Button>
        </div>

        {showSubmit && (
          <Card className="border-primary/20">
            <CardHeader><CardTitle className="text-lg">New Job Submission</CardTitle></CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2"><Label>Job Name</Label><Input placeholder="LLM Fine-tuning" value={jobName} onChange={(e) => setJobName(e.target.value)} /></div>
              <div className="grid sm:grid-cols-2 gap-4">
                <div className="space-y-2"><Label>Docker Image</Label><Input placeholder="myorg/llm-trainer:latest" value={dockerImage} onChange={(e) => setDockerImage(e.target.value)} /></div>
                <div className="space-y-2">
                  <Label>VRAM Required</Label>
                  <Select value={vram} onValueChange={setVram}><SelectTrigger><SelectValue placeholder="Select" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="10">10 GB</SelectItem>
                      <SelectItem value="24">24 GB</SelectItem>
                      <SelectItem value="40">40 GB</SelectItem>
                      <SelectItem value="80">80 GB</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="space-y-2">
                <Label>Budget (€/hr): €{(budget[0] / 10).toFixed(1)}</Label>
                <Slider value={budget} onValueChange={setBudget} max={100} step={1} />
              </div>
              <div className="flex items-center gap-3">
                <Switch id="green-tier" checked={greenOnly} onCheckedChange={setGreenOnly} />
                <Label htmlFor="green-tier">100% Recycled Energy Only (♻ Green Tier)</Label>
              </div>
              <Button className="w-full" onClick={handleSubmit} disabled={submitMutation.isPending}>
                {submitMutation.isPending ? "Submitting..." : "Submit to Smart Broker"}
              </Button>
            </CardContent>
          </Card>
        )}

        <Card>
          <CardHeader><CardTitle className="text-lg flex items-center gap-2"><BriefcaseBusiness className="h-5 w-5 text-primary" /> All Jobs</CardTitle></CardHeader>
          <CardContent className="space-y-3">
            {jobList.length === 0 && (
              <p className="text-sm text-muted-foreground text-center py-4">No jobs yet. Submit one above!</p>
            )}
            {jobList.map((j) => {
              const Icon = statusIcons[j.status] || Clock;
              const color = statusColors[j.status] || "bg-muted";
              return (
                <div key={j.id} className="flex items-center gap-4 p-3 rounded-lg border">
                  <div className={`h-8 w-8 rounded-full flex items-center justify-center ${color}/20`}>
                    <Icon className={`h-4 w-4 ${j.status === "running" ? "animate-spin text-primary" : "text-muted-foreground"}`} />
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-sm">{j.name}</span>
                      <Badge variant="outline" className="text-xs">{j.status}</Badge>
                      {j.tier === "Recycled" && <Badge className="bg-primary/20 text-primary text-xs border-0">♻</Badge>}
                      {j.tier === "Async" && <Badge variant="secondary" className="text-xs">⏳ Async</Badge>}
                    </div>
                    <p className="text-xs text-muted-foreground">{j.id} • {j.gpu} • ETA: {j.eta}</p>
                  </div>
                  <div className="w-24">
                    <Progress value={j.progress} className="h-2" />
                    <p className="text-xs text-right text-muted-foreground mt-0.5">{j.progress}%</p>
                  </div>
                </div>
              );
            })}
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}
