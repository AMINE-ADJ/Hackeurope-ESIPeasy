import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useTelemetry } from "@/hooks/useApi";
import { LoadingState, ErrorState } from "@/components/LoadingState";
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import { Cpu, Thermometer, Zap, Activity } from "lucide-react";

export default function Telemetry() {
  const { data, isLoading, error, refetch } = useTelemetry();

  if (isLoading) return <DashboardLayout><LoadingState /></DashboardLayout>;
  if (error || !data) return <DashboardLayout><ErrorState onRetry={() => refetch()} /></DashboardLayout>;

  const { gpu_telemetry, utilization_history } = data;

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold font-display">GPU Telemetry & Slicing</h1>
          <p className="text-muted-foreground text-sm">Monitor utilization, detect underused GPUs, and sub-lease fractional slices.</p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Cluster Utilization (24h)</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[250px]">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={utilization_history}>
                  <defs>
                    <linearGradient id="smGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="hsl(160,84%,39%)" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="hsl(160,84%,39%)" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="memGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="hsl(38,92%,50%)" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="hsl(38,92%,50%)" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="hour" tick={{ fontSize: 11 }} tickLine={false} axisLine={false} />
                  <YAxis tick={{ fontSize: 11 }} tickLine={false} axisLine={false} domain={[0, 100]} />
                  <Tooltip />
                  <Area type="monotone" dataKey="sm" name="SM Util %" stroke="hsl(160,84%,39%)" fill="url(#smGrad)" strokeWidth={2} />
                  <Area type="monotone" dataKey="mem" name="Memory %" stroke="hsl(38,92%,50%)" fill="url(#memGrad)" strokeWidth={2} />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {gpu_telemetry.map((g) => {
            const underused = g.smUtil < 70;
            return (
              <Card key={g.id} className={underused ? "border-primary/40" : ""}>
                <CardContent className="pt-5 space-y-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Cpu className="h-4 w-4" />
                      <span className="font-semibold">{g.gpu}</span>
                    </div>
                    {underused && <Badge className="bg-primary/20 text-primary text-xs border-0">Sub-lease Available</Badge>}
                  </div>

                  <div>
                    <p className="text-xs text-muted-foreground mb-1">MIG Slices ({g.slicesUsed}/{g.slicesTotal})</p>
                    <div className="flex gap-0.5">
                      {Array.from({ length: g.slicesTotal }).map((_, i) => (
                        <div
                          key={i}
                          className={`h-4 flex-1 rounded-sm ${i < g.slicesUsed ? "bg-primary" : "bg-muted"}`}
                        />
                      ))}
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-2 text-sm">
                    <div className="flex items-center gap-1.5">
                      <Activity className="h-3.5 w-3.5 text-muted-foreground" />
                      <span>SM: {g.smUtil}%</span>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <Cpu className="h-3.5 w-3.5 text-muted-foreground" />
                      <span>Mem: {g.memUtil}%</span>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <Thermometer className="h-3.5 w-3.5 text-muted-foreground" />
                      <span>{g.temp}°C</span>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <Zap className="h-3.5 w-3.5 text-muted-foreground" />
                      <span>{g.power}W</span>
                    </div>
                  </div>

                  {underused && (
                    <Button size="sm" className="w-full">List on Marketplace</Button>
                  )}
                </CardContent>
              </Card>
            );
          })}
        </div>
      </div>
    </DashboardLayout>
  );
}
