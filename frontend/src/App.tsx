import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { RoleProvider } from "@/contexts/RoleContext";
import Index from "./pages/Index";
import Dashboard from "./pages/Dashboard";
import Marketplace from "./pages/Marketplace";
import Telemetry from "./pages/Telemetry";
import Heatmap from "./pages/Heatmap";
import Onboarding from "./pages/Onboarding";
import Sustainability from "./pages/Sustainability";
import Jobs from "./pages/Jobs";
import AdminOverride from "./pages/AdminOverride";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <RoleProvider>
        <Toaster />
        <Sonner />
        <BrowserRouter>
          <Routes>
            <Route path="/" element={<Index />} />
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/marketplace" element={<Marketplace />} />
            <Route path="/telemetry" element={<Telemetry />} />
            <Route path="/heatmap" element={<Heatmap />} />
            <Route path="/onboarding" element={<Onboarding />} />
            <Route path="/sustainability" element={<Sustainability />} />
            <Route path="/jobs" element={<Jobs />} />
            <Route path="/admin/override" element={<AdminOverride />} />
            <Route path="/gpus" element={<Dashboard />} />
            <Route path="/settings" element={<Dashboard />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </BrowserRouter>
      </RoleProvider>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
