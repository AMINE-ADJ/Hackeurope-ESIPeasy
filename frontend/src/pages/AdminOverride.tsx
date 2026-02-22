import { useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useAdmin, useDeclareWasteEvent } from "@/hooks/useApi";
import { LoadingState, ErrorState } from "@/components/LoadingState";
import { useToast } from "@/hooks/use-toast";
import { Zap, AlertTriangle, Clock, Cpu, Flame } from "lucide-react";

export default function AdminOverride() {
  const { toast } = useToast();
  const { data, isLoading, error, refetch } = useAdmin();
  const declareEvent = useDeclareWasteEvent();
  const [source, setSource] = useState("");
  const [capacity, setCapacity] = useState("");
  const [location, setLocation] = useState("");

  const handleDeclare = () => {
    if (!source) return;
    declareEvent.mutate(
      { source, capacity_mw: parseFloat(capacity) || 1.5, location: location || "Unknown" },
      {
        onSuccess: (res: any) => {
          toast({ title: "Waste event declared!", description: `${res.gpus_activated ?? 0} GPUs spinning up…` });
          setSource(""); setCapacity(""); setLocation("");
        },
        onError: () => toast({ title: "Failed to declare event", variant: "destructive" }),
      }
    );
  };

  if (isLoading) return <DashboardLayout><LoadingState /></DashboardLayout>;
  if (error || !data) return <DashboardLayout><ErrorState onRetry={() => refetch()} /></DashboardLayout>;

  const { waste_events, cluster_overview } = data;

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold font-display flex items-center gap-2">
            <Zap className="h-6 w-6 text-primary" /> Crusoe Override Panel
          </h1>
          <p className="text-muted-foreground text-sm">Manually declare waste events and flood GPU clusters with surplus energy.</p>
        </div>

        <Card className="border-primary/30">
          <CardHeader>
            <CardTitle className="flex items-center gap-2"><AlertTriangle className="h-5 w-5 text-amber" /> Declare Waste Event</CardTitle>
            <CardDescription>Instantly activate dormant GPU clusters with stranded energy.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid sm:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label>Energy Source</Label>
                <Select value={source} onValueChange={setSource}>
                  <SelectTrigger><SelectValue placeholder="Select" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="flare_gas">Flare Gas</SelectItem>
                    <SelectItem value="solar_overcapacity">Solar Overcapacity</SelectItem>
                    <SelectItem value="wind_curtailment">Wind Curtailment</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2"><Label>Capacity (MW)</Label><Input type="number" placeholder="1.5" value={capacity} onChange={(e) => setCapacity(e.target.value)} /></div>
            </div>
            <div className="space-y-2"><Label>Location</Label><Input placeholder="Permian Basin, TX" value={location} onChange={(e) => setLocation(e.target.value)} /></div>
            <Button className="w-full" onClick={handleDeclare} disabled={declareEvent.isPending}>
              <Flame className="h-4 w-4 mr-2" /> {declareEvent.isPending ? "Declaring…" : "Declare Waste Event — Flood Cluster"}
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2"><Clock className="h-5 w-5 text-primary" /> Active Waste Events</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {waste_events.length === 0 ? (
              <p className="text-sm text-muted-foreground text-center py-4">No active waste events.</p>
            ) : waste_events.map((e: any) => (
              <div key={e.id} className="flex items-center justify-between p-4 rounded-lg border">
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 rounded-lg bg-amber-light flex items-center justify-center">
                    <Flame className="h-5 w-5 text-amber" />
                  </div>
                  <div>
                    <p className="font-medium text-sm">{e.source}</p>
                    <p className="text-xs text-muted-foreground">{e.capacity} capacity</p>
                  </div>
                </div>
                <div className="text-right">
                  <Badge variant="outline" className="mb-1">{e.time_left ?? e.timeLeft} remaining</Badge>
                  <p className="text-xs text-muted-foreground flex items-center gap-1 justify-end"><Cpu className="h-3 w-3" /> {e.gpus_activated ?? e.gpusActivated} GPUs active</p>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>

        <Card>
          <CardHeader><CardTitle className="text-lg">Global Cluster Overview</CardTitle></CardHeader>
          <CardContent>
            <div className="grid grid-cols-3 gap-4">
              <div className="text-center p-4 rounded-lg bg-muted">
                <p className="text-2xl font-bold font-display">{cluster_overview?.gamer_nodes ?? 0}</p>
                <p className="text-xs text-muted-foreground">Gamer Nodes</p>
              </div>
              <div className="text-center p-4 rounded-lg bg-muted">
                <p className="text-2xl font-bold font-display">{cluster_overview?.data_centers ?? 0}</p>
                <p className="text-xs text-muted-foreground">Data Centers</p>
              </div>
              <div className="text-center p-4 rounded-lg bg-muted">
                <p className="text-2xl font-bold font-display">{cluster_overview?.energy_recyclers ?? 0}</p>
                <p className="text-xs text-muted-foreground">Energy Recyclers</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}
