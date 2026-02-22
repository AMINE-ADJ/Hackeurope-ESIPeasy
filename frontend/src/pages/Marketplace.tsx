import { useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useMarketplace, useDeployOnNode } from "@/hooks/useApi";
import { LoadingState, ErrorState } from "@/components/LoadingState";
import { Search, Filter, Cpu, Leaf, MapPin, ArrowRight } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

const statusColors: Record<string, string> = { available: "bg-primary", busy: "bg-amber", offline: "bg-muted-foreground" };
const providerColors: Record<string, string> = { Gamer: "bg-blue-100 text-blue-700", "Data Center": "bg-purple-100 text-purple-700", Recycler: "bg-green-light text-primary" };

export default function Marketplace() {
  const [filter, setFilter] = useState("all");
  const [search, setSearch] = useState("");
  const { data, isLoading, error, refetch } = useMarketplace();
  const deploy = useDeployOnNode();
  const { toast } = useToast();

  if (isLoading) return <DashboardLayout><LoadingState /></DashboardLayout>;
  if (error || !data) return <DashboardLayout><ErrorState onRetry={() => refetch()} /></DashboardLayout>;

  const filtered = data.listings.filter((g) => {
    if (filter !== "all" && g.provider !== filter) return false;
    if (search && !g.gpu.toLowerCase().includes(search.toLowerCase())) return false;
    return true;
  });

  const handleDeploy = (nodeId: number, gpuName: string) => {
    deploy.mutate(
      { nodeId, name: `Deploy on ${gpuName}`, workload_type: "inference", duration_hours: 1 },
      {
        onSuccess: (res) => {
          toast({ title: "Deployed!", description: res.workload?.node ? `Running on ${res.workload.node}` : "Workload submitted." });
        },
        onError: () => {
          toast({ title: "Deploy failed", description: "Could not deploy workload.", variant: "destructive" });
        },
      }
    );
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold font-display">GPU Marketplace</h1>
          <p className="text-muted-foreground text-sm">Browse and deploy on the greenest, cheapest compute available.</p>
        </div>

        <div className="flex flex-wrap gap-3">
          <div className="relative flex-1 min-w-[200px]">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input placeholder="Search GPUs..." value={search} onChange={(e) => setSearch(e.target.value)} className="pl-9" />
          </div>
          <Select value={filter} onValueChange={setFilter}>
            <SelectTrigger className="w-[160px]">
              <Filter className="h-4 w-4 mr-2" />
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Providers</SelectItem>
              <SelectItem value="Gamer">Gamers</SelectItem>
              <SelectItem value="Data Center">Data Centers</SelectItem>
              <SelectItem value="Recycler">Recyclers</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <Card className="border-primary/20 bg-green-light/30">
          <CardContent className="pt-4 pb-4">
            <p className="text-sm font-medium mb-2">Smart Broker Priority Routing</p>
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
              <Badge className="bg-primary text-primary-foreground">1. Recycler</Badge>
              <ArrowRight className="h-3 w-3" />
              <Badge variant="secondary">2. Surplus DC</Badge>
              <ArrowRight className="h-3 w-3" />
              <Badge variant="outline">3. Green Gamer</Badge>
            </div>
          </CardContent>
        </Card>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {filtered.map((g) => {
            const greenScore = g.green_score ?? g.greenScore ?? 0;
            return (
              <Card key={g.id} className="hover:shadow-md transition-shadow">
                <CardContent className="pt-5 space-y-3">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Cpu className="h-4 w-4 text-muted-foreground" />
                      <span className="font-semibold text-sm">{g.gpu}</span>
                    </div>
                    <div className={`h-2 w-2 rounded-full ${statusColors[g.status] || "bg-muted-foreground"}`} />
                  </div>
                  <div className="flex flex-wrap gap-1.5">
                    <Badge variant="outline" className="text-xs">{g.vram}</Badge>
                    <Badge className={`text-xs border-0 ${providerColors[g.provider] || "bg-muted"}`}>{g.provider}</Badge>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <div className="flex items-center gap-1 text-muted-foreground">
                      <MapPin className="h-3 w-3" /> {g.location}
                    </div>
                    <span className="font-bold">€{g.price}/hr</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <Leaf className="h-3.5 w-3.5 text-primary" />
                    <div className="flex-1 h-1.5 bg-muted rounded-full overflow-hidden">
                      <div className="h-full bg-primary rounded-full" style={{ width: `${greenScore}%` }} />
                    </div>
                    <span className="text-xs font-medium">{greenScore}</span>
                  </div>
                  <Button
                    size="sm"
                    className="w-full"
                    disabled={g.status !== "available" || deploy.isPending}
                    onClick={() => handleDeploy(g.id, g.gpu)}
                  >
                    {g.status === "available" ? "Deploy" : g.status === "busy" ? "In Use" : "Offline"}
                  </Button>
                </CardContent>
              </Card>
            );
          })}
          {filtered.length === 0 && (
            <div className="col-span-full text-center py-8 text-muted-foreground text-sm">No GPUs match your filters.</div>
          )}
        </div>
      </div>
    </DashboardLayout>
  );
}
