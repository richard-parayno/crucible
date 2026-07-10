<script lang="ts">
  import { Link } from "@inertiajs/svelte"
  import { Bot, LayoutGrid, MonitorCheck } from "@lucide/svelte"

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
  import {
    agentsPath,
    dashboardPath,
    newAgentPath,
    systemCheckPath,
  } from "@/routes"
  import { type NavItem } from "@/types"

  import AppLogo from "./app-logo.svelte"

  const mainNavItems: NavItem[] = [
    {
      title: "Dashboard",
      href: dashboardPath(),
      icon: LayoutGrid,
    },
    {
      title: "Agents",
      href: agentsPath(),
      icon: Bot,
      items: [
        {
          title: "View Agents",
          href: agentsPath(),
        },
        {
          title: "Add Agents",
          href: newAgentPath(),
        },
      ],
    },
    {
      title: "System Check",
      href: systemCheckPath(),
      icon: MonitorCheck,
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
