<script lang="ts">
  import { MonitorCheck } from "@lucide/svelte"

  import SetupPreflight from "@/components/setup-preflight.svelte"
  import { Button } from "@/components/ui/button"
  import AppLayout from "@/layouts/app-layout.svelte"
  import { newAgentPath, systemCheckPath } from "@/routes"
  import type { BreadcrumbItem } from "@/types"

  interface RuntimeDefinition {
    kind: string
    name: string
  }

  interface AgentRuntimeRow {
    kind?: string
    name?: string
    status?: string
    pid?: number
    user?: string
    executable_path?: string
    working_directory?: string
    importable?: boolean
  }

  interface Props {
    host_capabilities: Record<string, unknown>
    runtime_definitions: RuntimeDefinition[]
    installed_binaries: AgentRuntimeRow[]
    host_processes: AgentRuntimeRow[]
    managed_runtimes: AgentRuntimeRow[]
  }

  let {
    host_capabilities: hostCapabilities,
    runtime_definitions: runtimeDefinitions,
    installed_binaries: installedBinaries,
    host_processes: hostProcesses,
    managed_runtimes: managedRuntimes,
  }: Props = $props()

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "System Check",
      href: systemCheckPath(),
    },
  ]
</script>

<svelte:head>
  <title>System Check</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <div class="flex h-full flex-col gap-6 p-4">
    <section
      class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between"
    >
      <div>
        <div class="flex items-center gap-2">
          <MonitorCheck class="size-5" />
          <h1 class="text-2xl font-semibold tracking-tight">System Check</h1>
        </div>
        <p class="text-muted-foreground mt-1 max-w-2xl text-sm">
          Host readiness for Docker Compose managed agents.
        </p>
      </div>

      <div class="flex flex-wrap gap-2">
        <Button href={newAgentPath()}>Add Agent</Button>
      </div>
    </section>

    <SetupPreflight
      {hostCapabilities}
      {runtimeDefinitions}
      {installedBinaries}
      {hostProcesses}
      {managedRuntimes}
    />
  </div>
</AppLayout>
