import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Leaf, Cpu, Zap, Globe, ArrowRight, BarChart3, Shield } from "lucide-react";
import { useDashboard } from "@/hooks/useApi";

const Index = () => {
  const { data } = useDashboard();
  const stats = data?.stats;

  return (
    <div className="min-h-screen bg-background">
      {/* Nav */}
      <nav className="border-b bg-card/80 backdrop-blur sticky top-0 z-50">
        <div className="container flex h-16 items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="h-9 w-9 rounded-lg bg-primary flex items-center justify-center">
              <Leaf className="h-5 w-5 text-primary-foreground" />
            </div>
            <span className="font-display text-xl font-bold">Too Green to Go</span>
          </div>
          <div className="flex items-center gap-3">
            <Link to="/dashboard">
              <Button variant="ghost" size="sm">Platform</Button>
            </Link>
            <Link to="/dashboard">
              <Button size="sm">Get Started <ArrowRight className="ml-1 h-4 w-4" /></Button>
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="container py-24 text-center">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-green-light text-primary text-sm font-medium mb-6">
          <Zap className="h-4 w-4" /> Energy-Aware GPU Compute
        </div>
        <h1 className="font-display text-5xl md:text-6xl font-bold tracking-tight max-w-3xl mx-auto leading-tight">
          Turn Wasted Energy Into <span className="text-primary">AI Power</span>
        </h1>
        <p className="mt-6 text-lg text-muted-foreground max-w-2xl mx-auto">
          The world's first green GPU arbitrage platform. We match AI workloads to surplus energy and idle compute — cutting costs and carbon emissions simultaneously.
        </p>
        <div className="mt-10 flex items-center justify-center gap-4">
          <Link to="/dashboard">
            <Button size="lg" className="font-semibold">
              Explore Platform <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
          </Link>
          <Link to="/onboarding">
            <Button size="lg" variant="outline" className="font-semibold">
              Become a Provider
            </Button>
          </Link>
        </div>
      </section>

      {/* Stats */}
      <section className="border-y bg-muted/30">
        <div className="container py-12 grid grid-cols-2 md:grid-cols-4 gap-8">
          {[
            { label: "CO₂ Saved", value: (stats?.co2_saved ?? stats?.co2Saved ?? "--") + " tons", icon: Leaf },
            { label: "GPU-Hours Brokered", value: stats?.gpu_hours ?? stats?.gpuHoursBrokered ?? "--", icon: Cpu },
            { label: "Energy Recovered", value: stats?.energy_recovered ?? stats?.energyRecovered ?? "--", icon: Zap },
            { label: "Active Providers", value: stats?.active_providers ?? stats?.activeProviders ?? "--", icon: Globe },
          ].map((s) => (
            <div key={s.label} className="text-center">
              <s.icon className="h-6 w-6 mx-auto mb-2 text-primary" />
              <div className="font-display text-3xl font-bold">{s.value}</div>
              <div className="text-sm text-muted-foreground mt-1">{s.label}</div>
            </div>
          ))}
        </div>
      </section>

      {/* Value Props */}
      <section className="container py-20">
        <h2 className="font-display text-3xl font-bold text-center mb-12">Three Pillars of Green Compute</h2>
        <div className="grid md:grid-cols-3 gap-6">
          {[
            {
              icon: Shield,
              title: "B2B — Data Center Optimization",
              desc: "Detect surplus energy windows and underutilized GPUs. Automatically slice and sub-lease fractional GPU capacity to maximize utilization and reduce waste.",
            },
            {
              icon: Globe,
              title: "B2C — Community Marketplace",
              desc: "Gamers and individuals lease idle GPUs — but only when their local grid is green. Carbon-compliant compute from the community.",
            },
            {
              icon: BarChart3,
              title: "Smart Brokerage",
              desc: "Our orchestrator matches async AI workloads to the cheapest, greenest compute globally. Recyclers first, then surplus DCs, then green gamers.",
            },
          ].map((v) => (
            <Card key={v.title} className="border-0 shadow-md hover:shadow-lg transition-shadow">
              <CardContent className="pt-6">
                <div className="h-12 w-12 rounded-xl bg-green-light flex items-center justify-center mb-4">
                  <v.icon className="h-6 w-6 text-primary" />
                </div>
                <h3 className="font-display text-lg font-semibold mb-2">{v.title}</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{v.desc}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t py-8">
        <div className="container flex items-center justify-between text-sm text-muted-foreground">
          <span>© 2025 Too Green to Go — Hackathon Demo</span>
          <span className="flex items-center gap-1"><Leaf className="h-4 w-4 text-primary" /> Built for a greener future</span>
        </div>
      </footer>
    </div>
  );
};

export default Index;
