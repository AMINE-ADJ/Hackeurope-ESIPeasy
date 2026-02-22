import React, { createContext, useContext, useState, ReactNode } from "react";

export type Role = "gamer" | "datacenter" | "recycler" | "developer" | "admin";

export const ROLE_LABELS: Record<Role, string> = {
  gamer: "Gamer",
  datacenter: "Data Center",
  recycler: "Energy Recycler",
  developer: "AI Developer",
  admin: "Admin",
};

export const ROLE_COLORS: Record<Role, string> = {
  gamer: "bg-blue-500",
  datacenter: "bg-purple-500",
  recycler: "bg-primary",
  developer: "bg-orange-500",
  admin: "bg-foreground",
};

interface RoleContextType {
  role: Role;
  setRole: (role: Role) => void;
}

const RoleContext = createContext<RoleContextType | undefined>(undefined);

export function RoleProvider({ children }: { children: ReactNode }) {
  const [role, setRole] = useState<Role>("developer");
  return (
    <RoleContext.Provider value={{ role, setRole }}>
      {children}
    </RoleContext.Provider>
  );
}

export function useRole() {
  const context = useContext(RoleContext);
  if (!context) throw new Error("useRole must be used within RoleProvider");
  return context;
}
