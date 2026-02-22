import { useRole, Role, ROLE_LABELS } from "@/contexts/RoleContext";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { SidebarTrigger } from "@/components/ui/sidebar";
import { Badge } from "@/components/ui/badge";

const roles: Role[] = ["gamer", "datacenter", "recycler", "developer", "admin"];

export function TopBar() {
  const { role, setRole } = useRole();

  return (
    <header className="h-14 border-b flex items-center justify-between px-4 bg-card">
      <div className="flex items-center gap-3">
        <SidebarTrigger />
        <span className="text-sm text-muted-foreground hidden sm:inline">Energy-Aware GPU Arbitrage Platform</span>
      </div>
      <div className="flex items-center gap-3">
        <span className="text-xs text-muted-foreground">Viewing as:</span>
        <Select value={role} onValueChange={(v) => setRole(v as Role)}>
          <SelectTrigger className="w-[160px] h-8">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {roles.map((r) => (
              <SelectItem key={r} value={r}>{ROLE_LABELS[r]}</SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Badge variant="outline" className="text-xs border-primary text-primary">Demo Mode</Badge>
      </div>
    </header>
  );
}
