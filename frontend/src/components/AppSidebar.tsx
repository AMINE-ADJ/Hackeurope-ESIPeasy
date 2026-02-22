import {
  LayoutDashboard, ShoppingCart, Cpu, BriefcaseBusiness, Leaf, Settings, Globe, Users, Zap, MonitorSmartphone,
} from "lucide-react";
import { NavLink } from "@/components/NavLink";
import { useRole, Role } from "@/contexts/RoleContext";
import {
  Sidebar, SidebarContent, SidebarGroup, SidebarGroupContent, SidebarGroupLabel,
  SidebarMenu, SidebarMenuButton, SidebarMenuItem, SidebarHeader,
} from "@/components/ui/sidebar";

type NavItem = { title: string; url: string; icon: React.ElementType; roles: Role[] };

const navItems: NavItem[] = [
  { title: "Dashboard", url: "/dashboard", icon: LayoutDashboard, roles: ["gamer", "datacenter", "recycler", "developer", "admin"] },
  { title: "Marketplace", url: "/marketplace", icon: ShoppingCart, roles: ["gamer", "datacenter", "recycler", "developer", "admin"] },
  { title: "My GPUs", url: "/gpus", icon: Cpu, roles: ["gamer", "datacenter", "recycler"] },
  { title: "GPU Telemetry", url: "/telemetry", icon: MonitorSmartphone, roles: ["datacenter", "admin"] },
  { title: "Jobs", url: "/jobs", icon: BriefcaseBusiness, roles: ["developer", "admin"] },
  { title: "Sustainability", url: "/sustainability", icon: Leaf, roles: ["gamer", "datacenter", "recycler", "developer", "admin"] },
  { title: "Onboarding", url: "/onboarding", icon: Users, roles: ["gamer", "datacenter", "recycler"] },
];

const adminItems: NavItem[] = [
  { title: "Override Panel", url: "/admin/override", icon: Zap, roles: ["admin"] },
  { title: "Global Heatmap", url: "/heatmap", icon: Globe, roles: ["admin", "developer"] },
  { title: "Settings", url: "/settings", icon: Settings, roles: ["gamer", "datacenter", "recycler", "developer", "admin"] },
];

export function AppSidebar() {
  const { role } = useRole();
  const filtered = navItems.filter((i) => i.roles.includes(role));
  const filteredAdmin = adminItems.filter((i) => i.roles.includes(role));

  return (
    <Sidebar className="border-r-0">
      <SidebarHeader className="p-4 border-b border-sidebar-border">
        <NavLink to="/" className="flex items-center gap-2 no-underline">
          <div className="h-8 w-8 rounded-lg bg-sidebar-primary flex items-center justify-center">
            <Leaf className="h-5 w-5 text-sidebar-primary-foreground" />
          </div>
          <span className="font-display text-lg font-bold text-sidebar-foreground">Too Green to Go</span>
        </NavLink>
      </SidebarHeader>
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel className="text-sidebar-foreground/50 text-xs uppercase tracking-wider">Navigation</SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {filtered.map((item) => (
                <SidebarMenuItem key={item.title}>
                  <SidebarMenuButton asChild>
                    <NavLink to={item.url} end className="hover:bg-sidebar-accent" activeClassName="bg-sidebar-accent text-sidebar-primary font-medium">
                      <item.icon className="mr-2 h-4 w-4" />
                      <span>{item.title}</span>
                    </NavLink>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
        {filteredAdmin.length > 0 && (
          <SidebarGroup>
            <SidebarGroupLabel className="text-sidebar-foreground/50 text-xs uppercase tracking-wider">System</SidebarGroupLabel>
            <SidebarGroupContent>
              <SidebarMenu>
                {filteredAdmin.map((item) => (
                  <SidebarMenuItem key={item.title}>
                    <SidebarMenuButton asChild>
                      <NavLink to={item.url} end className="hover:bg-sidebar-accent" activeClassName="bg-sidebar-accent text-sidebar-primary font-medium">
                        <item.icon className="mr-2 h-4 w-4" />
                        <span>{item.title}</span>
                      </NavLink>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                ))}
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        )}
      </SidebarContent>
    </Sidebar>
  );
}
