<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"
  import { Boxes, Play, RefreshCw, Square, Stethoscope } from "@lucide/svelte"
  import { onMount } from "svelte"

  import HeadingSmall from "@/components/heading-small.svelte"
  import InputError from "@/components/input-error.svelte"
  import { Badge } from "@/components/ui/badge"
  import { Button } from "@/components/ui/button"
  import { Input } from "@/components/ui/input"
  import { Label } from "@/components/ui/label"
  import AppLayout from "@/layouts/app-layout.svelte"
  import {
    checkHealthWorkspaceRuntimeInstancePath,
    restartWorkspaceRuntimeInstancePath,
    startWorkspaceRuntimeInstancePath,
    stopWorkspaceRuntimeInstancePath,
    workspacePath,
    workspaceRuntimeInstancesPath,
    workspacesPath,
  } from "@/routes"
  import type { BreadcrumbItem } from "@/types"

  interface RuntimeEvent {
    id: number
    level: "debug" | "info" | "warn" | "error"
    message: string
    occurred_at: string
  }

  interface RuntimeInstance {
    id: number
    name: string
    status: string
    placement_kind: string
    runtime_kind: string
    runtime_name: string
    container_runtime: string
    container_name?: string
    status_message?: string
    started_at?: string
    stopped_at?: string
    recent_events: RuntimeEvent[]
  }

  interface RuntimeDefinition {
    id: number
    kind: string
    name: string
    description?: string
    container_image: string
    default_command: string
  }

  interface WorkspaceSummary {
    id: number
    name: string
  }

  interface Workspace {
    id: number
    name: string
    runtime_instances: RuntimeInstance[]
  }

  interface Props {
    workspace: Workspace
    workspaces: WorkspaceSummary[]
    runtime_definitions: RuntimeDefinition[]
    host_capabilities: Record<string, unknown>
  }

  let {
    workspace,
    workspaces,
    runtime_definitions: runtimeDefinitions,
    host_capabilities: hostCapabilities,
  }: Props = $props()

  let runtimeInstances = $state<RuntimeInstance[]>(workspace.runtime_instances)
  let selectedRuntimeDefinitionId = $state(
    runtimeDefinitions[0]?.id?.toString() ?? "",
  )
  let selectedInstanceId = $state<number | null>(
    runtimeInstances[0]?.id ?? null,
  )

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Workspaces",
      href: workspacesPath(),
    },
    {
      title: workspace.name,
      href: workspacePath(workspace.id),
    },
  ]

  const selectedRuntimeDefinition = $derived(
    runtimeDefinitions.find(
      (runtimeDefinition) =>
        runtimeDefinition.id.toString() === selectedRuntimeDefinitionId,
    ) ?? runtimeDefinitions[0],
  )

  const selectedInstance = $derived(
    runtimeInstances.find(
      (runtimeInstance) => runtimeInstance.id === selectedInstanceId,
    ) ?? runtimeInstances[0],
  )

  const configTemplate = $derived(
    JSON.stringify(
      {
        container_image: selectedRuntimeDefinition?.container_image ?? "",
        command: selectedRuntimeDefinition?.default_command ?? "",
      },
      null,
      2,
    ),
  )

  function upsertInstance(instance: RuntimeInstance) {
    const existingIndex = runtimeInstances.findIndex(
      (runtimeInstance) => runtimeInstance.id === instance.id,
    )

    if (existingIndex >= 0) {
      runtimeInstances[existingIndex] = instance
    } else {
      runtimeInstances = [instance, ...runtimeInstances]
    }

    selectedInstanceId ??= instance.id
  }

  function appendEvent(runtimeInstanceId: number, event: RuntimeEvent) {
    const instance = runtimeInstances.find(
      (runtimeInstance) => runtimeInstance.id === runtimeInstanceId,
    )
    if (!instance) return

    instance.recent_events = [...instance.recent_events, event].slice(-100)
  }

  function statusTone(status: string) {
    if (status === "running")
      return "bg-emerald-50 text-emerald-700 border-emerald-200"
    if (status === "failed") return "bg-red-50 text-red-700 border-red-200"
    if (status === "unhealthy")
      return "bg-amber-50 text-amber-700 border-amber-200"
    if (["starting", "stopping"].includes(status)) {
      return "bg-blue-50 text-blue-700 border-blue-200"
    }
    return "bg-muted text-muted-foreground border-border"
  }

  function capabilityStatus(path: string[]) {
    let value: unknown = hostCapabilities

    for (const key of path) {
      if (!value || typeof value !== "object") return "unknown"
      value = (value as Record<string, unknown>)[key]
    }

    if (!value || typeof value !== "object") return "unknown"

    return (
      ((value as Record<string, unknown>).status as string | undefined) ??
      "unknown"
    )
  }

  onMount(() => {
    const protocol = window.location.protocol === "https:" ? "wss" : "ws"
    const socket = new WebSocket(`${protocol}://${window.location.host}/cable`)
    const identifier = JSON.stringify({
      channel: "RuntimeInstancesChannel",
      workspace_id: workspace.id,
    })

    socket.addEventListener("open", () => {
      socket.send(JSON.stringify({ command: "subscribe", identifier }))
    })

    socket.addEventListener("message", (event) => {
      const payload = JSON.parse(event.data)
      if (payload.type || !payload.message) return

      if (payload.message.type === "runtime_instance") {
        upsertInstance(payload.message.instance)
      }

      if (payload.message.type === "runtime_event") {
        appendEvent(payload.message.runtime_instance_id, payload.message.event)
        upsertInstance(payload.message.instance)
      }
    })

    return () => socket.close()
  })
</script>

<svelte:head>
  <title>{workspace.name}</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <div class="flex h-full flex-col gap-6 p-4">
    <section
      class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between"
    >
      <div>
        <div class="flex items-center gap-2">
          <Boxes class="size-5" />
          <h1 class="text-2xl font-semibold tracking-tight">
            {workspace.name}
          </h1>
        </div>
        <p class="text-muted-foreground mt-1 max-w-2xl text-sm">
          Local-only supervisor for Docker Compose managed agent runtimes.
        </p>
        <div class="mt-3 flex flex-wrap gap-2">
          <Badge variant="outline"
            >Docker {capabilityStatus(["container", "docker"])}</Badge
          >
          <Badge variant="outline"
            >Compose {capabilityStatus(["container", "docker_compose"])}</Badge
          >
          <Badge variant="outline"
            >Tailscale {capabilityStatus(["networking", "tailscale"])}</Badge
          >
        </div>
      </div>

      <Form method="post" action={workspacesPath()} class="flex gap-2">
        {#snippet children({ errors, processing }: FormComponentSlotProps)}
          <div>
            <Input name="name" placeholder="New workspace" required />
            <InputError messages={errors.name} />
          </div>
          <Button type="submit" disabled={processing}>Create</Button>
        {/snippet}
      </Form>
    </section>

    <div class="grid gap-4 xl:grid-cols-[220px_minmax(0,1fr)]">
      <aside class="border-border rounded-lg border p-3">
        <HeadingSmall title="Workspaces" description="Local control planes" />
        <div class="mt-4 flex flex-col gap-1">
          {#each workspaces as item (item.id)}
            <Button
              variant={item.id === workspace.id ? "secondary" : "ghost"}
              class="justify-start"
              href={workspacePath(item.id)}
            >
              {item.name}
            </Button>
          {/each}
        </div>
      </aside>

      <div class="grid gap-4 xl:grid-cols-[minmax(0,420px)_minmax(0,1fr)]">
        <section class="border-border rounded-lg border p-4">
          <HeadingSmall
            title="Add runtime"
            description="Choose an agent template and run it as a Docker Compose project."
          />

          <Form
            method="post"
            action={workspaceRuntimeInstancesPath(workspace.id)}
            class="mt-5 space-y-4"
          >
            {#snippet children({ errors, processing }: FormComponentSlotProps)}
              <div class="grid gap-2">
                <Label for="runtime_definition_id">Runtime</Label>
                <select
                  id="runtime_definition_id"
                  name="runtime_definition_id"
                  bind:value={selectedRuntimeDefinitionId}
                  class="border-input bg-background ring-offset-background focus-visible:ring-ring h-9 rounded-md border px-3 text-sm focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none"
                >
                  {#each runtimeDefinitions as runtimeDefinition (runtimeDefinition.id)}
                    <option value={runtimeDefinition.id}>
                      {runtimeDefinition.name}
                    </option>
                  {/each}
                </select>
              </div>

              <div class="grid gap-2">
                <Label for="name">Name</Label>
                <Input
                  id="name"
                  name="name"
                  placeholder={selectedRuntimeDefinition?.name ?? "Runtime"}
                />
                <InputError messages={errors.name} />
              </div>

              <div class="grid gap-2">
                <Label for="config">Config JSON</Label>
                <textarea
                  id="config"
                  name="config"
                  rows="7"
                  class="border-input bg-background ring-offset-background focus-visible:ring-ring min-h-32 rounded-md border px-3 py-2 font-mono text-xs focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none"
                  value={configTemplate}></textarea>
                <InputError messages={errors.config} />
              </div>

              <div class="grid gap-2">
                <Label for="env">Environment JSON</Label>
                <textarea
                  id="env"
                  name="env"
                  rows="4"
                  class="border-input bg-background ring-offset-background focus-visible:ring-ring rounded-md border px-3 py-2 font-mono text-xs focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none"
                  value={"{}"}></textarea>
              </div>

              <Button type="submit" disabled={processing}>Add runtime</Button>
            {/snippet}
          </Form>
        </section>

        <section class="flex min-w-0 flex-col gap-4">
          <div class="border-border rounded-lg border">
            <div
              class="border-border flex items-center justify-between border-b p-4"
            >
              <HeadingSmall
                title="Runtime instances"
                description="Start, stop, restart, and inspect local containers."
              />
            </div>

            {#if runtimeInstances.length === 0}
              <div class="text-muted-foreground p-6 text-sm">
                No runtimes yet. Add one to start exercising the local
                orchestration loop.
              </div>
            {:else}
              <div class="divide-border divide-y">
                {#each runtimeInstances as runtimeInstance (runtimeInstance.id)}
                  <button
                    class="hover:bg-muted/50 flex w-full items-center justify-between gap-3 p-4 text-left"
                    type="button"
                    onclick={() => (selectedInstanceId = runtimeInstance.id)}
                  >
                    <div class="min-w-0">
                      <p class="truncate font-medium">{runtimeInstance.name}</p>
                      <p class="text-muted-foreground truncate text-xs">
                        {runtimeInstance.runtime_name} via Docker Compose
                        {#if runtimeInstance.container_name}
                          · {runtimeInstance.container_name}
                        {/if}
                      </p>
                    </div>
                    <span
                      class={`rounded-md border px-2 py-1 text-xs font-medium ${statusTone(runtimeInstance.status)}`}
                    >
                      {runtimeInstance.status}
                    </span>
                  </button>
                {/each}
              </div>
            {/if}
          </div>

          {#if selectedInstance}
            <div class="border-border rounded-lg border p-4">
              <div
                class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between"
              >
                <div>
                  <div class="flex items-center gap-2">
                    <h2 class="text-lg font-semibold">
                      {selectedInstance.name}
                    </h2>
                    <Badge variant="outline"
                      >{selectedInstance.runtime_kind}</Badge
                    >
                  </div>
                  {#if selectedInstance.status_message}
                    <p class="text-muted-foreground mt-1 text-sm">
                      {selectedInstance.status_message}
                    </p>
                  {/if}
                </div>

                <div class="flex flex-wrap gap-2">
                  <Form
                    method="post"
                    action={startWorkspaceRuntimeInstancePath(
                      workspace.id,
                      selectedInstance.id,
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
                      workspace.id,
                      selectedInstance.id,
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
                      workspace.id,
                      selectedInstance.id,
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
                      workspace.id,
                      selectedInstance.id,
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

              <div class="mt-5 overflow-hidden rounded-lg border bg-black">
                <div
                  class="border-white/10 border-b px-3 py-2 text-xs font-medium text-white/70"
                >
                  Recent logs and lifecycle events
                </div>
                <div
                  class="max-h-[420px] min-h-56 overflow-auto p-3 font-mono text-xs text-white"
                >
                  {#if selectedInstance.recent_events.length === 0}
                    <p class="text-white/50">No runtime events yet.</p>
                  {:else}
                    {#each selectedInstance.recent_events as event (event.id)}
                      <div
                        class="grid gap-3 py-1 md:grid-cols-[160px_48px_minmax(0,1fr)]"
                      >
                        <span class="text-white/40">{event.occurred_at}</span>
                        <span class="uppercase text-white/60"
                          >{event.level}</span
                        >
                        <span class="break-words">{event.message}</span>
                      </div>
                    {/each}
                  {/if}
                </div>
              </div>
            </div>
          {/if}
        </section>
      </div>
    </div>
  </div>
</AppLayout>
