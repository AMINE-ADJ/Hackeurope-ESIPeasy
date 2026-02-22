import { useRole } from "@/contexts/RoleContext";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { useDashboard } from "@/hooks/useApi";
import { LoadingState, ErrorState } from "@/components/LoadingState";
import { Leaf, Cpu, Zap, TrendingDown, Activity, DollarSign } from "lucide-react";
import { Progress } from "@/components/ui/progress";

function StatCard({ icon: Icon, label, value, sub }: { icon: React.ElementType; label: string; value: string; sub?: string }) {
  return (
    <Card>
      <CardContent className="pt-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm text-muted-foreground">{label}</p>
            <p className="text-2xl font-bold font-display mt-1">{value}</p>
            {sub && <p className="text-xs text-primary mt-1">{sub}</p>}
          </div>
          <div className="h-10 w-10 rounded-lg bg-green-light flex items-center justify-center">
            <Icon className="h-5 w-5 text-primary" />
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

export default function Dashboard() {
  const { role } = useRole();
  const { data, isLoading, error, refetch } = useDashboard();

  if (isLoading) return <DashboardLayout><LoadingState /></DashboardLayout>;
  if (error || !data) return <DashboardLayout><ErrorState onRetry={() => refetch()} /></DashboardLayout>;

  const { stats, surplus_events, energy_providers, jobs, gpu_fleet } = data;

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold font-display">Dashboard</h1>
          <p className="text-muted-foreground text-sm">Welcome back. Here's your live overview.</p>
        </div>

        {/* Stats row */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard icon={Leaf} label="CO₂ Saved" value={stats.co2_saved} sub={`${stats.completed_workloads} jobs completed`} />
          <StatCard icon={Cpu} label="GPU-Hours" value={stats.gpu_hours_brokered} sub={`${stats.total_nodes} nodes`} />
          <StatCard icon={Zap} label="Energy Recovered" value={stats.energy_recovered} />
          <StatCard icon={DollarSign} label="Avg Savings" value={stats.avg_savings} sub="vs. traditional cloud" />
        </div>

        <div className="grid lg:grid-cols-2 gap-6">
          {/* Surplus Events */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <TrendingDown className="h-5 w-5 text-primary" /> Live Surplus Events
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {surplus_events.length === 0 && (
                <p className="text-sm text-muted-foreground text-center py-4">No active surplus events. Run a grid simulation to generate data.</p>
              )}
              {surplus_events.map((e) => (
                <div key={e.id} className="flex items-center justify-between p-3 rounded-lg bg-green-light/50">
                  <div>
                    <p className="font-medium text-sm">{e.provider} — {e.region}</p>
                    <p className="text-xs text-muted-foreground">{e.capacity} available • {e.time}</p>
                  </div>
                  <Badge className="bg-primary text-primary-foreground">{e.drop}</Badge>
                </div>
              ))}
            </CardContent>
          </Card>

          {/* Energy Providers */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Activity className="h-5 w-5 text-primary" /> Energy Grid Status
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                {energy_providers.map((p) => (
                  <div key={p.name} className="flex items-center justify-between p-2 rounded-lg hover:bg-muted/50">
                    <div className="flex items-center gap-3">
                      <div className={`h-2.5 w-2.5 rounded-full ${p.status === "green" ? "bg-primary" : p.status === "amber" ? "bg-amber" : "bg-destructive"}`} />
                      <div>
                        <p className="font-medium text-sm">{p.name}</p>
                        <p className="text-xs text-muted-foreground">{p.region}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-medium">€{p.spot_price ?? p.spotPrice}/MWh</p>
                      <p className="text-xs text-muted-foreground">{p.carbon_intensity ?? p.carbonIntensity} gCO₂/kWh</p>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Active Jobs (developer/admin) */}
        {(role === "developer" || role === "admin") && (
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Active Jobs</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {jobs.filter((j) => j.status !== "completed").map((j) => (
                  <div key={j.id} className="flex items-center gap-4 p-3 rounded-lg bg-muted/30">
                    <div className="flex-1">
                      <div className="flex items-center gap-2">
                        <p className="font-medium text-sm">{j.name}</p>
                        <Badge variant={j.status === "running" ? "default" : "secondary"} className="text-xs">
                          {j.status}
                        </Badge>
                        {j.tier === "Recycled" && <Badge className="bg-primary/20 text-primary text-xs border-0">♻ Recycled</Badge>}
                      </div>
                      <p className="text-xs text-muted-foreground mt-1">{j.id} • {j.gpu} • ETA: {j.eta}</p>
                    </div>
                    <div className="w-32">
                      <Progress value={j.progress} className="h-2" />
                    </div>
                  </div>
                ))}
                {jobs.filter((j) => j.status !== "completed").length === 0 && (
                  <p className="text-sm text-muted-foreground text-center py-4">No active jobs.</p>
                )}
              </div>
            </CardContent>
          </Card>
        )}

        {/* GPU Overview (provider roles) */}
        {(role === "datacenter" || role === "recycler") && (
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">GPU Fleet Status</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">
                {gpu_fleet.map((g) => {
                  const smUtil = g.sm_util ?? g.smUtil ?? 0;
                  const memUtil = g.mem_util ?? g.memUtil ?? 0;
                  return (
                    <div key={g.id} className="p-3 rounded-lg border">
                      <div className="flex items-center justify-between mb-2">
                        <span className="font-medium text-sm">{g.gpu}</span>
                        {smUtil < 70 && <Badge variant="outline" className="text-xs border-primary text-primary">Sub-lease Available</Badge>}
                      </div>
                      <div className="space-y-1">
                        <div className="flex justify-between text-xs text-muted-foreground">
                          <span>SM: {smUtil}%</span><span>Mem: {memUtil}%</span>
                        </div>
                        <Progress value={smUtil} className="h-1.5" />
                      </div>
                    </div>
                  );
                })}
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </DashboardLayout>
  );
}
