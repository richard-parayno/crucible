<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"
  import {
    ArrowLeft,
    Bot,
    Box,
    Clock,
    Container,
    Play,
    RefreshCw,
    Square,
    Stethoscope,
  } from "@lucide/svelte"

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
    checkHealthWorkspaceRuntimeInstancePath,
    dashboardPath,
    restartWorkspaceRuntimeInstancePath,
    startWorkspaceRuntimeInstancePath,
    stopWorkspaceRuntimeInstancePath,
  } from "@/routes"
  import type { BreadcrumbItem } from "@/types"

  interface WorkspaceSummary {
    id: number
    name: string
  }

  interface Agent {
    id: number
    name: string
    status: string
    placement_kind: string
    container_runtime: string
    container_name?: string
    compose_project?: ComposeProject | null
    runtime_kind: string
    runtime_name: string
    status_message?: string
    started_at?: string
    last_heartbeat_at?: string
    workspace: WorkspaceSummary
  }

  interface ComposeProject {
    directory_path: string
    compose_path: string
    env_path: string
    project_name: string
    service_name: string
  }

  interface Props {
    agent: Agent
  }

  let { agent }: Props = $props()

  const breadcrumbs = $derived([
    {
      title: "Dashboard",
      href: dashboardPath(),
    },
    {
      title: agent.name,
      href: agentPath(agent.id),
    },
  ] satisfies BreadcrumbItem[])

  const composeProject = $derived(agent.compose_project)

  function statusTone(status: string) {
    if (status === "running")
      return "border-emerald-200 bg-emerald-50 text-emerald-700"
    if (status === "failed") return "border-red-200 bg-red-50 text-red-700"
    if (status === "unhealthy")
      return "border-amber-200 bg-amber-50 text-amber-700"
    if (["starting", "stopping"].includes(status)) {
      return "border-blue-200 bg-blue-50 text-blue-700"
    }
    return "border-border bg-muted text-muted-foreground"
  }

  function formatDateTime(value?: string) {
    if (!value) return "Not recorded"

    return new Intl.DateTimeFormat(undefined, {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(value))
  }
</script>

<svelte:head>
  <title>{agent.name}</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <div class="flex h-full flex-col gap-6 p-4">
    <section
      class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between"
    >
      <div class="min-w-0">
        <div class="flex flex-wrap items-center gap-2">
          <Bot class="size-5" />
          <h1 class="truncate text-2xl font-semibold tracking-tight">
            {agent.name}
          </h1>
          <Badge class={statusTone(agent.status)}>{agent.status}</Badge>
        </div>
        <p class="text-muted-foreground mt-2 text-sm">
          {agent.runtime_name} in {agent.workspace.name}
        </p>
      </div>

      <div class="flex flex-wrap gap-2">
        <Button variant="outline" href={dashboardPath()}>
          <ArrowLeft class="size-4" />
          Dashboard
        </Button>
      </div>
    </section>

    <section class="border-border rounded-lg border p-4">
      <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h2 class="text-sm font-medium">Runtime Controls</h2>
          <p class="text-muted-foreground mt-1 text-sm">
            Queue lifecycle work for this agent.
          </p>
        </div>

        <div class="flex flex-wrap gap-2">
          <Form
            method="post"
            action={startWorkspaceRuntimeInstancePath(
              agent.workspace.id,
              agent.id,
            )}
          >
            {#snippet children({ processing }: FormComponentSlotProps)}
              <Button type="submit" size="sm" disabled={processing}>
                <Play class="size-4" />
                Start
              </Button>
            {/snippet}
          </Form>

          <Form
            method="post"
            action={stopWorkspaceRuntimeInstancePath(
              agent.workspace.id,
              agent.id,
            )}
          >
            {#snippet children({ processing }: FormComponentSlotProps)}
              <Button
                type="submit"
                size="sm"
                variant="outline"
                disabled={processing}
              >
                <Square class="size-4" />
                Stop
              </Button>
            {/snippet}
          </Form>

          <Form
            method="post"
            action={restartWorkspaceRuntimeInstancePath(
              agent.workspace.id,
              agent.id,
            )}
          >
            {#snippet children({ processing }: FormComponentSlotProps)}
              <Button
                type="submit"
                size="sm"
                variant="outline"
                disabled={processing}
              >
                <RefreshCw class="size-4" />
                Restart
              </Button>
            {/snippet}
          </Form>

          <Form
            method="post"
            action={checkHealthWorkspaceRuntimeInstancePath(
              agent.workspace.id,
              agent.id,
            )}
          >
            {#snippet children({ processing }: FormComponentSlotProps)}
              <Button
                type="submit"
                size="sm"
                variant="ghost"
                disabled={processing}
              >
                <Stethoscope class="size-4" />
                Check
              </Button>
            {/snippet}
          </Form>
        </div>
      </div>
    </section>

    <section
      class="grid gap-4"
      style="grid-template-columns: repeat(auto-fit, minmax(min(18rem, 100%), 1fr));"
    >
      <Card>
        <CardHeader class="flex flex-row items-center justify-between gap-4">
          <CardTitle class="text-sm font-medium">Runtime</CardTitle>
          <Bot class="text-muted-foreground size-4" />
        </CardHeader>
        <CardContent class="space-y-2 text-sm">
          <div>
            <div class="text-muted-foreground">Agent</div>
            <div class="font-medium">{agent.runtime_name}</div>
          </div>
          <div>
            <div class="text-muted-foreground">Kind</div>
            <div class="font-medium">{agent.runtime_kind}</div>
          </div>
          <div>
            <div class="text-muted-foreground">Placement</div>
            <div class="font-medium">{agent.placement_kind}</div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader class="flex flex-row items-center justify-between gap-4">
          <CardTitle class="text-sm font-medium">Container</CardTitle>
          <Container class="text-muted-foreground size-4" />
        </CardHeader>
        <CardContent class="space-y-2 text-sm">
          <div>
            <div class="text-muted-foreground">Runtime</div>
            <div class="font-medium">{agent.container_runtime}</div>
          </div>
          <div>
            <div class="text-muted-foreground">Container</div>
            <div class="break-all font-medium">
              {agent.container_name ?? "Not assigned"}
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader class="flex flex-row items-center justify-between gap-4">
          <CardTitle class="text-sm font-medium">Activity</CardTitle>
          <Clock class="text-muted-foreground size-4" />
        </CardHeader>
        <CardContent class="space-y-2 text-sm">
          <div>
            <div class="text-muted-foreground">Started</div>
            <div class="font-medium">{formatDateTime(agent.started_at)}</div>
          </div>
          <div>
            <div class="text-muted-foreground">Last heartbeat</div>
            <div class="font-medium">
              {formatDateTime(agent.last_heartbeat_at)}
            </div>
          </div>
        </CardContent>
      </Card>
    </section>

    {#if agent.status_message}
      <section class="border-border rounded-lg border p-4">
        <h2 class="text-sm font-medium">Status Message</h2>
        <p class="text-muted-foreground mt-2 text-sm">{agent.status_message}</p>
      </section>
    {/if}

    <section class="border-border rounded-lg border p-4">
      <div class="flex items-center gap-2">
        <Box class="size-4" />
        <h2 class="text-sm font-medium">Compose Project</h2>
      </div>

      {#if composeProject}
        <dl
          class="mt-4 grid gap-3 text-sm"
          style="grid-template-columns: repeat(auto-fit, minmax(min(18rem, 100%), 1fr));"
        >
          <div>
            <dt class="text-muted-foreground">Project</dt>
            <dd class="break-all font-medium">{composeProject.project_name}</dd>
          </div>
          <div>
            <dt class="text-muted-foreground">Service</dt>
            <dd class="break-all font-medium">{composeProject.service_name}</dd>
          </div>
          <div>
            <dt class="text-muted-foreground">Directory</dt>
            <dd class="break-all font-medium">
              {composeProject.directory_path}
            </dd>
          </div>
          <div>
            <dt class="text-muted-foreground">Compose file</dt>
            <dd class="break-all font-medium">{composeProject.compose_path}</dd>
          </div>
        </dl>
      {:else}
        <p class="text-muted-foreground mt-3 text-sm">
          Compose metadata has not been prepared for this agent yet.
        </p>
      {/if}
    </section>
  </div>
</AppLayout>
