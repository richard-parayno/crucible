<script lang="ts">
  import { Activity, ArrowRight, Bot, Folder, Plus } from "@lucide/svelte"

  import { Badge } from "@/components/ui/badge"
  import { Button } from "@/components/ui/button"
  import {
    Card,
    CardContent,
    CardHeader,
    CardTitle,
  } from "@/components/ui/card"
  import AppLayout from "@/layouts/app-layout.svelte"
  import {
    agentPath,
    dashboardPath,
    newAgentPath,
  } from "@/routes"
  import { type BreadcrumbItem } from "@/types"

  interface WorkspaceSummary {
    id: number
    name: string
  }

  interface RunningAgent {
    id: number
    name: string
    status: string
    runtime_kind: string
    runtime_name: string
    container_name?: string
    status_message?: string
    started_at?: string
    workspace: WorkspaceSummary
  }

  interface Props {
    agent_count: number
    running_agents: RunningAgent[]
  }

  let {
    agent_count: agentCount,
    running_agents: runningAgents,
  }: Props = $props()

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Dashboard",
      href: dashboardPath(),
    },
  ]

  function formatDateTime(value?: string) {
    if (!value) return "Not recorded"

    return new Intl.DateTimeFormat(undefined, {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(value))
  }

  function runtimeLabel(agent: RunningAgent) {
    return agent.runtime_name || agent.runtime_kind
  }
</script>

<svelte:head>
  <title>{breadcrumbs[breadcrumbs.length - 1].title}</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <div class="flex h-full flex-1 flex-col gap-6 p-4">
    <section class="max-w-sm">
      <Card>
        <CardHeader class="flex flex-row items-center justify-between gap-4">
          <CardTitle class="text-sm font-medium">Detected Agents</CardTitle>
          <Bot class="text-muted-foreground size-4" />
        </CardHeader>
        <CardContent>
          <div class="text-3xl font-semibold tracking-tight">{agentCount}</div>
          <p class="text-muted-foreground mt-2 text-sm">
            Agent instances configured on this Crucible host.
          </p>
        </CardContent>
      </Card>
    </section>

    <section class="border-border rounded-lg border">
      <div
        class="border-border flex flex-col gap-3 border-b p-4 sm:flex-row sm:items-center sm:justify-between"
      >
        <div>
          <div class="flex items-center gap-2">
            <Activity class="size-4" />
            <h1 class="text-base font-semibold">Running Agents</h1>
          </div>
          <p class="text-muted-foreground mt-1 text-sm">
            Live agents currently running on this Crucible host.
          </p>
        </div>

        <Button href={newAgentPath()} size="sm">
          <Plus class="size-4" />
          Add Agent
        </Button>
      </div>

      {#if runningAgents.length > 0}
        <div class="divide-border divide-y">
          {#each runningAgents as agent (agent.id)}
            <article class="grid gap-4 p-4">
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-2">
                  <h2 class="truncate text-sm font-medium">{agent.name}</h2>
                  <Badge
                    class="border-emerald-200 bg-emerald-50 text-emerald-700"
                  >
                    {agent.status}
                  </Badge>
                </div>
                <div class="text-muted-foreground mt-2 grid gap-1 text-sm">
                  <div>{runtimeLabel(agent)}</div>
                  <div class="flex items-center gap-1.5">
                    <Folder class="size-3.5" />
                    {agent.workspace.name}
                  </div>
                  {#if agent.container_name}
                    <div>{agent.container_name}</div>
                  {/if}
                </div>
                {#if agent.status_message}
                  <p class="text-muted-foreground mt-2 text-sm">
                    {agent.status_message}
                  </p>
                {/if}
              </div>

              <div class="text-muted-foreground text-sm">
                <div class="text-foreground font-medium">Started</div>
                <div class="mt-1">{formatDateTime(agent.started_at)}</div>
              </div>

              <div class="flex items-start">
                <Button variant="outline" size="sm" href={agentPath(agent.id)}>
                  View Agent
                  <ArrowRight class="size-4" />
                </Button>
              </div>
            </article>
          {/each}
        </div>
      {:else}
        <div class="p-8 text-center">
          <Bot class="text-muted-foreground mx-auto size-8" />
          <h2 class="mt-3 text-sm font-medium">No running agents</h2>
          <p class="text-muted-foreground mx-auto mt-2 max-w-sm text-sm">
            Add an agent to see it here.
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
