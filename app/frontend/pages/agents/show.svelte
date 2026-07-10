<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"
  import {
    ArrowLeft,
    Bot,
    Box,
    Clock,
    Container,
    FileText,
    KeyRound,
    ListChecks,
    Play,
    RefreshCw,
    Square,
    Stethoscope,
    Terminal,
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
    stopped_at?: string
    last_heartbeat_at?: string
    config: Record<string, string | boolean | null>
    runtime_env: RuntimeEnv[]
    environment_variables: EnvironmentVariable[]
    recent_agent_runs: AgentRun[]
    recent_events: RuntimeEvent[]
    workspace: WorkspaceSummary
  }

  interface ComposeProject {
    directory_path: string
    compose_path: string
    env_path: string
    project_name: string
    service_name: string
    commands: Record<string, string[]>
  }

  interface RuntimeEnv {
    key: string
    value: string
    source: string
  }

  interface EnvironmentVariable {
    id: number
    key: string
    value: string
    scope: string
    sensitive: boolean
    enabled: boolean
  }

  interface AgentRun {
    id: number
    command: string
    status: string
    exit_code?: number
    output?: string
    status_message?: string
    started_at?: string
    finished_at?: string
    created_at: string
  }

  interface RuntimeEvent {
    id: number
    level: string
    message: string
    metadata: Record<string, unknown>
    occurred_at: string
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
  const configEntries = $derived(Object.entries(agent.config ?? {}))
  const environmentRows = $derived([
    ...(agent.runtime_env ?? []),
    ...(agent.environment_variables ?? []).map((variable) => ({
      key: variable.key,
      value: variable.value,
      source: variable.scope,
    })),
  ])

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

  function commandText(command: string[]) {
    return command.join(" ")
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
      <div
        class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between"
      >
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
          <div>
            <div class="text-muted-foreground">Stopped</div>
            <div class="font-medium">{formatDateTime(agent.stopped_at)}</div>
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
          <div>
            <dt class="text-muted-foreground">Env file</dt>
            <dd class="break-all font-medium">{composeProject.env_path}</dd>
          </div>
        </dl>

        <div class="mt-5">
          <div class="flex items-center gap-2">
            <Terminal class="size-4" />
            <h3 class="text-sm font-medium">Docker Compose Commands</h3>
          </div>
          <div class="mt-3 grid gap-2">
            {#each Object.entries(composeProject.commands) as [name, command] (name)}
              <div class="grid gap-1 text-sm">
                <div class="text-muted-foreground capitalize">
                  {name.replaceAll("_", " ")}
                </div>
                <code
                  class="bg-muted text-muted-foreground block overflow-x-auto rounded-md px-3 py-2 text-xs"
                >
                  {commandText(command)}
                </code>
              </div>
            {/each}
          </div>
        </div>
      {:else}
        <p class="text-muted-foreground mt-3 text-sm">
          Compose metadata has not been prepared for this agent yet.
        </p>
      {/if}
    </section>

    <section
      class="grid gap-4"
      style="grid-template-columns: repeat(auto-fit, minmax(min(22rem, 100%), 1fr));"
    >
      <section class="border-border rounded-lg border p-4">
        <div class="flex items-center gap-2">
          <FileText class="size-4" />
          <h2 class="text-sm font-medium">Runtime Config</h2>
        </div>

        {#if configEntries.length > 0}
          <dl class="mt-4 grid gap-3 text-sm">
            {#each configEntries as [key, value] (key)}
              <div>
                <dt class="text-muted-foreground">{key}</dt>
                <dd class="break-all font-medium">{value?.toString()}</dd>
              </div>
            {/each}
          </dl>
        {:else}
          <p class="text-muted-foreground mt-3 text-sm">
            No runtime config has been recorded.
          </p>
        {/if}
      </section>

      <section class="border-border rounded-lg border p-4">
        <div class="flex items-center gap-2">
          <KeyRound class="size-4" />
          <h2 class="text-sm font-medium">Environment</h2>
        </div>

        {#if environmentRows.length > 0}
          <div class="mt-4 overflow-x-auto">
            <table class="w-full min-w-96 text-left text-sm">
              <thead class="text-muted-foreground border-b text-xs">
                <tr>
                  <th class="py-2 pr-3 font-medium">Key</th>
                  <th class="py-2 pr-3 font-medium">Value</th>
                  <th class="py-2 font-medium">Source</th>
                </tr>
              </thead>
              <tbody>
                {#each environmentRows as row (row.source + row.key)}
                  <tr class="border-b last:border-0">
                    <td class="py-2 pr-3 font-medium">{row.key}</td>
                    <td class="py-2 pr-3 font-mono text-xs">{row.value}</td>
                    <td class="text-muted-foreground py-2">{row.source}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {:else}
          <p class="text-muted-foreground mt-3 text-sm">
            No runtime-specific environment variables are configured.
          </p>
        {/if}
      </section>
    </section>

    <section
      class="grid gap-4"
      style="grid-template-columns: repeat(auto-fit, minmax(min(22rem, 100%), 1fr));"
    >
      <section class="border-border rounded-lg border p-4">
        <div class="flex items-center gap-2">
          <ListChecks class="size-4" />
          <h2 class="text-sm font-medium">Recent Command Runs</h2>
        </div>

        {#if agent.recent_agent_runs.length > 0}
          <div class="mt-4 space-y-3">
            {#each agent.recent_agent_runs as run (run.id)}
              <article class="border-border rounded-md border p-3">
                <div class="flex flex-wrap items-center justify-between gap-2">
                  <code class="font-mono text-xs">{run.command}</code>
                  <Badge variant="outline">{run.status}</Badge>
                </div>
                <div class="text-muted-foreground mt-2 text-xs">
                  {formatDateTime(
                    run.finished_at ?? run.started_at ?? run.created_at,
                  )}
                  {#if run.exit_code !== undefined && run.exit_code !== null}
                    · exit {run.exit_code}
                  {/if}
                </div>
                {#if run.status_message}
                  <p class="text-muted-foreground mt-2 text-sm">
                    {run.status_message}
                  </p>
                {/if}
                {#if run.output}
                  <pre
                    class="bg-muted text-muted-foreground mt-2 max-h-40 overflow-auto rounded-md p-2 text-xs">{run.output}</pre>
                {/if}
              </article>
            {/each}
          </div>
        {:else}
          <p class="text-muted-foreground mt-3 text-sm">
            No command runs have been recorded.
          </p>
        {/if}
      </section>

      <section class="border-border rounded-lg border p-4">
        <div class="flex items-center gap-2">
          <Clock class="size-4" />
          <h2 class="text-sm font-medium">Lifecycle Events and Logs</h2>
        </div>

        {#if agent.recent_events.length > 0}
          <div class="mt-4 space-y-3">
            {#each agent.recent_events as event (event.id)}
              <article class="border-border rounded-md border p-3">
                <div class="flex flex-wrap items-center justify-between gap-2">
                  <Badge variant="outline">{event.level}</Badge>
                  <time class="text-muted-foreground text-xs">
                    {formatDateTime(event.occurred_at)}
                  </time>
                </div>
                <p class="mt-2 break-words text-sm">{event.message}</p>
              </article>
            {/each}
          </div>
        {:else}
          <p class="text-muted-foreground mt-3 text-sm">
            No lifecycle events or Compose logs have been captured.
          </p>
        {/if}
      </section>
    </section>
  </div>
</AppLayout>
