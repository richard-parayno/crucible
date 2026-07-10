<script lang="ts">
  import {
    Activity,
    ArrowRight,
    Bot,
    Clock,
    Folder,
    Plus,
    Terminal,
  } from "@lucide/svelte"

  import { Badge } from "@/components/ui/badge"
  import { Button } from "@/components/ui/button"
  import AppLayout from "@/layouts/app-layout.svelte"
  import { agentsPath, newAgentPath } from "@/routes"
  import type { BreadcrumbItem } from "@/types"

  interface WorkspaceSummary {
    id?: number
    name?: string
  }

  type TokenUsage =
    | number
    | string
    | {
        total?: number
        total_tokens?: number
        input?: number
        output?: number
      }

  interface RunUsage {
    total_count?: number
    completed_count?: number
    running_count?: number
    last_run_at?: string
  }

  interface AgentRuntimeRow {
    id: number | string
    row_id?: string
    source: string
    name?: string
    kind?: string
    status?: string
    workspace?: string | WorkspaceSummary | null
    working_directory?: string
    executable_path?: string
    token_usage?: TokenUsage | null
    run_usage?: RunUsage | null
    last_activity_at?: string
    agent_path?: string
  }

  interface Props {
    agent_runtimes: AgentRuntimeRow[]
  }

  let { agent_runtimes: agentRuntimes }: Props = $props()

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Agents",
      href: agentsPath(),
    },
  ]

  function statusTone(status?: string) {
    if (status === "running" || status === "active") {
      return "border-emerald-200 bg-emerald-50 text-emerald-700"
    }

    if (status === "failed" || status === "error") {
      return "border-red-200 bg-red-50 text-red-700"
    }

    if (status === "unhealthy" || status === "warning") {
      return "border-amber-200 bg-amber-50 text-amber-700"
    }

    if (status && ["starting", "stopping", "queued"].includes(status)) {
      return "border-blue-200 bg-blue-50 text-blue-700"
    }

    return "border-border bg-muted text-muted-foreground"
  }

  function sourceTone(source: string) {
    if (source === "auto_detected") {
      return "border-blue-200 bg-blue-50 text-blue-700"
    }

    if (source === "manual") {
      return "border-violet-200 bg-violet-50 text-violet-700"
    }

    return "border-border bg-background text-muted-foreground"
  }

  function titleize(value?: string) {
    if (!value) return "Unknown"

    return value
      .replace(/[_-]+/g, " ")
      .replace(/\b\w/g, (character) => character.toUpperCase())
  }

  function workspaceName(workspace?: string | WorkspaceSummary | null) {
    if (!workspace) return "Not assigned"
    if (typeof workspace === "string") return workspace

    return workspace.name ?? "Not assigned"
  }

  function displayName(agentRuntime: AgentRuntimeRow) {
    return (
      agentRuntime.name || agentRuntime.row_id || `Agent ${agentRuntime.id}`
    )
  }

  function formatDateTime(value?: string) {
    if (!value) return "No activity"

    return new Intl.DateTimeFormat(undefined, {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(value))
  }

  function formatTokenUsage(tokenUsage?: TokenUsage | null) {
    if (tokenUsage === null || tokenUsage === undefined || tokenUsage === "") {
      return "Not tracked"
    }

    if (typeof tokenUsage === "number") {
      return tokenUsage.toLocaleString()
    }

    if (typeof tokenUsage === "string") {
      return tokenUsage
    }

    const total = tokenUsage.total ?? tokenUsage.total_tokens
    if (total !== undefined) return total.toLocaleString()

    const input = tokenUsage.input ?? 0
    const output = tokenUsage.output ?? 0
    const calculatedTotal = input + output

    return calculatedTotal > 0
      ? calculatedTotal.toLocaleString()
      : "Not tracked"
  }

  function formatRunUsage(runUsage?: RunUsage | null) {
    if (!runUsage) return "No runs recorded"

    const totalCount = runUsage.total_count ?? 0
    const completedCount = runUsage.completed_count ?? 0
    const runningCount = runUsage.running_count ?? 0

    return `${totalCount.toLocaleString()} runs, ${completedCount.toLocaleString()} done, ${runningCount.toLocaleString()} running`
  }
</script>

<svelte:head>
  <title>Agents</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <div class="flex h-full flex-1 flex-col gap-6 p-4">
    <section
      class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between"
    >
      <div class="min-w-0">
        <div class="flex items-center gap-2">
          <Bot class="size-5" />
          <h1 class="text-2xl font-semibold tracking-tight">Agents</h1>
        </div>
        <p class="text-muted-foreground mt-2 max-w-2xl text-sm">
          Auto-detected and manually added runtimes available to this workspace.
        </p>
      </div>

      <Button href={newAgentPath()}>
        <Plus class="size-4" />
        Add Agent
      </Button>
    </section>

    <section class="border-border overflow-hidden rounded-lg border">
      <div
        class="border-border flex flex-col gap-3 border-b p-4 sm:flex-row sm:items-center sm:justify-between"
      >
        <div>
          <div class="flex items-center gap-2">
            <Activity class="size-4" />
            <h2 class="text-base font-semibold">Runtime Inventory</h2>
          </div>
          <p class="text-muted-foreground mt-1 text-sm">
            {agentRuntimes.length}
            {agentRuntimes.length === 1 ? "runtime" : "runtimes"} registered.
          </p>
        </div>
      </div>

      {#if agentRuntimes.length > 0}
        <div class="overflow-x-auto">
          <table class="w-full min-w-[58rem] text-left text-sm">
            <thead class="bg-muted/40 text-muted-foreground">
              <tr class="border-border border-b">
                <th class="px-4 py-3 font-medium">Agent</th>
                <th class="px-4 py-3 font-medium">Source</th>
                <th class="px-4 py-3 font-medium">Status</th>
                <th class="px-4 py-3 font-medium">Workspace</th>
                <th class="px-4 py-3 font-medium">Runtime Path</th>
                <th class="px-4 py-3 font-medium">Token Usage</th>
                <th class="px-4 py-3 font-medium">Last Activity</th>
                <th class="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody class="divide-border divide-y">
              {#each agentRuntimes as agentRuntime (agentRuntime.row_id ?? agentRuntime.id)}
                <tr class="hover:bg-muted/30">
                  <td class="px-4 py-3 align-top">
                    <div class="max-w-56 min-w-0">
                      <div class="truncate font-medium">
                        {displayName(agentRuntime)}
                      </div>
                      <div class="text-muted-foreground mt-1 truncate text-xs">
                        {agentRuntime.kind ?? "Unknown kind"}
                      </div>
                    </div>
                  </td>
                  <td class="px-4 py-3 align-top">
                    <Badge
                      variant="outline"
                      class={sourceTone(agentRuntime.source)}
                    >
                      {titleize(agentRuntime.source)}
                    </Badge>
                  </td>
                  <td class="px-4 py-3 align-top">
                    <Badge
                      variant="outline"
                      class={statusTone(agentRuntime.status)}
                    >
                      {titleize(agentRuntime.status)}
                    </Badge>
                  </td>
                  <td class="px-4 py-3 align-top">
                    <div class="flex max-w-44 items-center gap-1.5">
                      <Folder class="text-muted-foreground size-3.5 shrink-0" />
                      <span class="truncate">
                        {workspaceName(agentRuntime.workspace)}
                      </span>
                    </div>
                  </td>
                  <td class="px-4 py-3 align-top">
                    <div class="max-w-72 min-w-0 space-y-1">
                      {#if agentRuntime.working_directory}
                        <div class="flex items-center gap-1.5">
                          <Terminal
                            class="text-muted-foreground size-3.5 shrink-0"
                          />
                          <span class="truncate font-mono text-xs">
                            {agentRuntime.working_directory}
                          </span>
                        </div>
                      {/if}
                      {#if agentRuntime.executable_path}
                        <div
                          class="text-muted-foreground truncate font-mono text-xs"
                        >
                          {agentRuntime.executable_path}
                        </div>
                      {/if}
                      {#if !agentRuntime.working_directory && !agentRuntime.executable_path}
                        <span class="text-muted-foreground text-xs">
                          Not detected
                        </span>
                      {/if}
                    </div>
                  </td>
                  <td class="px-4 py-3 align-top">
                    <div class="max-w-40 space-y-1">
                      <div class="tabular-nums">
                        {formatTokenUsage(agentRuntime.token_usage)}
                      </div>
                      <div class="text-muted-foreground text-xs">
                        {formatRunUsage(agentRuntime.run_usage)}
                      </div>
                    </div>
                  </td>
                  <td class="px-4 py-3 align-top">
                    <div class="flex max-w-44 items-center gap-1.5">
                      <Clock class="text-muted-foreground size-3.5 shrink-0" />
                      <span class="truncate">
                        {formatDateTime(agentRuntime.last_activity_at)}
                      </span>
                    </div>
                  </td>
                  <td class="px-4 py-3 text-right align-top">
                    {#if agentRuntime.agent_path}
                      <Button
                        href={agentRuntime.agent_path}
                        variant="outline"
                        size="sm"
                      >
                        View
                        <ArrowRight class="size-4" />
                      </Button>
                    {/if}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {:else}
        <div class="p-8 text-center">
          <Bot class="text-muted-foreground mx-auto size-8" />
          <h2 class="mt-3 text-sm font-medium">No agents found</h2>
          <p class="text-muted-foreground mx-auto mt-2 max-w-sm text-sm">
            Add an agent or run host detection to populate the runtime
            inventory.
          </p>
          <Button
            href={newAgentPath()}
            variant="outline"
            size="sm"
            class="mt-4"
          >
            <Plus class="size-4" />
            Add Agent
          </Button>
        </div>
      {/if}
    </section>
  </div>
</AppLayout>
