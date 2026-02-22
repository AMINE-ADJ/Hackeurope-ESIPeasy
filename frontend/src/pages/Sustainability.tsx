import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useRole } from "@/contexts/RoleContext";
import { useSustainability } from "@/hooks/useApi";
import { LoadingState, ErrorState } from "@/components/LoadingState";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, Legend } from "recharts";
import { Leaf, DollarSign, Zap, TrendingUp, Wallet } from "lucide-react";

export default function Sustainability() {
  const { role } = useRole();
  const isProvider = ["gamer", "datacenter", "recycler"].includes(role);
  const { data, isLoading, error, refetch } = useSustainability();

  if (isLoading) return <DashboardLayout><LoadingState /></DashboardLayout>;
  if (error || !data) return <DashboardLayout><ErrorState onRetry={() => refetch()} /></DashboardLayout>;

  const { stats, pricing_history, transactions } = data;

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold font-display">Sustainability & Financials</h1>
          <p className="text-muted-foreground text-sm">{isProvider ? "Track your earnings and environmental impact." : "Track your savings, carbon offset, and job history."}</p>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <Card><CardContent className="pt-6"><div className="flex items-center gap-3"><div className="h-10 w-10 rounded-lg bg-green-light flex items-center justify-center"><Leaf className="h-5 w-5 text-primary" /></div><div><p className="text-sm text-muted-foreground">CO₂ Offset</p><p className="text-xl font-bold font-display">{stats.co2_saved ?? stats.co2Saved} t</p></div></div></CardContent></Card>
          <Card><CardContent className="pt-6"><div className="flex items-center gap-3"><div className="h-10 w-10 rounded-lg bg-green-light flex items-center justify-center"><DollarSign className="h-5 w-5 text-primary" /></div><div><p className="text-sm text-muted-foreground">{isProvider ? "Revenue" : "Savings"}</p><p className="text-xl font-bold font-display">€{stats.revenue ?? stats.savings ?? '0'}</p></div></div></CardContent></Card>
          <Card><CardContent className="pt-6"><div className="flex items-center gap-3"><div className="h-10 w-10 rounded-lg bg-green-light flex items-center justify-center"><Zap className="h-5 w-5 text-primary" /></div><div><p className="text-sm text-muted-foreground">Energy Recovered</p><p className="text-xl font-bold font-display">{stats.energy_recovered ?? stats.energyRecovered}</p></div></div></CardContent></Card>
          <Card><CardContent className="pt-6"><div className="flex items-center gap-3"><div className="h-10 w-10 rounded-lg bg-green-light flex items-center justify-center"><Wallet className="h-5 w-5 text-primary" /></div><div><p className="text-sm text-muted-foreground">Wallet</p><p className="text-xl font-bold font-display">€{stats.wallet ?? '0.00'}</p></div></div></CardContent></Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2"><TrendingUp className="h-5 w-5 text-primary" /> Dynamic Pricing (30d)</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[280px]">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={pricing_history}>
                  <XAxis dataKey="day" tick={{ fontSize: 10 }} tickLine={false} axisLine={false} />
                  <YAxis tick={{ fontSize: 11 }} tickLine={false} axisLine={false} unit="€" />
                  <Tooltip />
                  <Legend />
                  <Line type="monotone" dataKey="recycled" name="Recycled" stroke="hsl(160,84%,39%)" strokeWidth={2} dot={false} />
                  <Line type="monotone" dataKey="standard" name="Standard DC" stroke="hsl(38,92%,50%)" strokeWidth={2} dot={false} />
                  <Line type="monotone" dataKey="gamer" name="Gamer" stroke="hsl(220,70%,55%)" strokeWidth={2} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader><CardTitle className="text-lg">Recent Transactions</CardTitle></CardHeader>
          <CardContent>
            <div className="space-y-2">
              {transactions.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">No transactions yet.</p>
              ) : transactions.map((t: any) => (
                <div key={t.id} className="flex items-center justify-between p-3 rounded-lg hover:bg-muted/50">
                  <div>
                    <p className="font-medium text-sm">{t.job}</p>
                    <p className="text-xs text-muted-foreground">{t.date} • {t.type}</p>
                  </div>
                  <span className={`font-semibold text-sm ${String(t.amount).startsWith("+") ? "text-primary" : "text-muted-foreground"}`}>{t.amount}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}
