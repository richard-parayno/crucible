<script lang="ts">
  import { Link } from "@inertiajs/svelte"
  import { Boxes, LayoutGrid } from "@lucide/svelte"

  import NavMain from "@/components/nav-main.svelte"
  import NavUser from "@/components/nav-user.svelte"
  import {
    Sidebar,
    SidebarContent,
    SidebarFooter,
    SidebarHeader,
    SidebarMenu,
    SidebarMenuButton,
    SidebarMenuItem,
  } from "@/components/ui/sidebar"
  import { dashboardPath, workspacesPath } from "@/routes"
  import { type NavItem } from "@/types"

  import AppLogo from "./app-logo.svelte"

  const mainNavItems: NavItem[] = [
    {
      title: "Dashboard",
      href: dashboardPath(),
      icon: LayoutGrid,
    },
    {
      title: "Workspaces",
      href: workspacesPath(),
      icon: Boxes,
    },
  ]
</script>

<Sidebar collapsible="icon" variant="inset">
  <SidebarHeader>
    <SidebarMenu>
      <SidebarMenuItem>
        <SidebarMenuButton size="lg">
          {#snippet child({ props })}
            <Link {...props} href={dashboardPath()}>
              <AppLogo />
            </Link>
          {/snippet}
        </SidebarMenuButton>
      </SidebarMenuItem>
    </SidebarMenu>
  </SidebarHeader>

  <SidebarContent>
    <NavMain items={mainNavItems} />
  </SidebarContent>

  <SidebarFooter>
    <NavUser />
  </SidebarFooter>
</Sidebar>
