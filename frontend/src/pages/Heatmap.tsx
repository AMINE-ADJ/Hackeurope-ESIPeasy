import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { useHeatmap } from "@/hooks/useApi";
import { LoadingState, ErrorState } from "@/components/LoadingState";
import { Globe, Zap, TrendingDown } from "lucide-react";

const statusLabel: Record<string, string> = { green: "Low Carbon", amber: "Moderate", red: "High Carbon" };
const statusBg: Record<string, string> = { green: "bg-primary/20 text-primary", amber: "bg-amber/20 text-amber-foreground", red: "bg-destructive/20 text-destructive" };
const dotColor: Record<string, string> = { green: "bg-primary", amber: "bg-amber", red: "bg-destructive" };

export default function Heatmap() {
  const { data, isLoading, error, refetch } = useHeatmap();

  if (isLoading) return <DashboardLayout><LoadingState /></DashboardLayout>;
  if (error || !data) return <DashboardLayout><ErrorState onRetry={() => refetch()} /></DashboardLayout>;

  const { regions, energy_providers, surplus_events } = data;

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold font-display flex items-center gap-2">
            <Globe className="h-6 w-6 text-primary" /> Global Energy Heatmap
          </h1>
          <p className="text-muted-foreground text-sm">Real-time energy prices and carbon intensity by region.</p>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-3">
          {regions.map((r: any) => (
            <Card key={r.id} className="hover:shadow-md transition-shadow">
              <CardContent className="pt-4 pb-4 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="font-medium text-sm">{r.name}</span>
                  <div className={`h-2.5 w-2.5 rounded-full ${dotColor[r.status] || 'bg-muted'}`} />
                </div>
                <div className="text-xs text-muted-foreground space-y-1">
                  <div className="flex justify-between"><span>Price</span><span className="font-medium text-foreground">€{r.price}/MWh</span></div>
                  <div className="flex justify-between"><span>Carbon</span><span className="font-medium text-foreground">{r.carbon} gCO₂</span></div>
                </div>
                <Badge className={`text-xs border-0 ${statusBg[r.status] || ''}`}>{statusLabel[r.status] || r.status}</Badge>
              </CardContent>
            </Card>
          ))}
        </div>

        <div className="grid lg:grid-cols-2 gap-6">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Zap className="h-5 w-5 text-primary" /> Energy Provider Data
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              {energy_providers.map((p: any) => (
                <div key={p.name} className="flex items-center justify-between p-3 rounded-lg hover:bg-muted/50">
                  <div className="flex items-center gap-3">
                    <div className={`h-3 w-3 rounded-full ${dotColor[p.status] || 'bg-muted'}`} />
                    <div>
                      <p className="font-medium text-sm">{p.name}</p>
                      <p className="text-xs text-muted-foreground">{p.region}</p>
                    </div>
                  </div>
                  <div className="text-right text-sm">
                    <p className="font-medium">€{p.spot_price ?? p.spotPrice}/MWh</p>
                    <p className="text-xs text-muted-foreground">{p.carbon_intensity ?? p.carbonIntensity} gCO₂/kWh</p>
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <TrendingDown className="h-5 w-5 text-primary" /> Surplus Events Feed
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {surplus_events.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">No active surplus events.</p>
              ) : surplus_events.map((e: any) => (
                <div key={e.id} className="flex items-center justify-between p-3 rounded-lg bg-green-light/50">
                  <div>
                    <p className="font-medium text-sm">{e.provider} — {e.region}</p>
                    <p className="text-xs text-muted-foreground">{e.capacity} • {e.time}</p>
                  </div>
                  <Badge className="bg-primary text-primary-foreground">{e.drop}</Badge>
                </div>
              ))}
            </CardContent>
          </Card>
        </div>
      </div>
    </DashboardLayout>
  );
}
