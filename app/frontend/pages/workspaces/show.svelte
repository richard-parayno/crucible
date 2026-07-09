<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"
  import {
    Boxes,
    Play,
    Power,
    RefreshCw,
    Save,
    Square,
    Stethoscope,
    Trash2,
  } from "@lucide/svelte"
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
    workspaceEnvironmentVariablePath,
    workspaceEnvironmentVariablesPath,
    workspacePath,
    workspaceRuntimeInstanceAgentRunsPath,
    workspaceRuntimeInstanceEnvironmentVariablePath,
    workspaceRuntimeInstanceEnvironmentVariablesPath,
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
    environment_variables: EnvironmentVariable[]
    recent_agent_runs: AgentRun[]
    recent_events: RuntimeEvent[]
  }

  interface AgentRun {
    id: number
    command: string
    status: string
    exit_code?: number
    output?: string
    status_message?: string
    created_at: string
    started_at?: string
    finished_at?: string
  }

  interface EnvironmentVariable {
    id: number
    scope: "system" | "runtime_instance"
    key: string
    value: string
    sensitive: boolean
    enabled: boolean
    runtime_instance_id?: number
    value_present: boolean
  }

  interface RuntimeDefinition {
    id: number
    kind: string
    name: string
    description?: string
    container_image: string
    default_command: string
    config_schema?: {
      default_template_mode?: string
      templates?: RuntimeTemplate[]
    }
  }

  interface RuntimeTemplate {
    mode: string
    name: string
    description?: string
    container_image?: string
    default_command?: string
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
    system_environment_variables: EnvironmentVariable[]
    selected_runtime_instance_id?: number | null
    host_capabilities: Record<string, unknown>
  }

  let {
    workspace,
    workspaces,
    runtime_definitions: runtimeDefinitions,
    system_environment_variables: systemEnvironmentVariables,
    selected_runtime_instance_id: selectedRuntimeInstanceId = null,
    host_capabilities: hostCapabilities,
  }: Props = $props()

  let runtimeInstances = $state<RuntimeInstance[]>(workspace.runtime_instances)
  let selectedRuntimeDefinitionId = $state(
    runtimeDefinitions[0]?.id?.toString() ?? "",
  )
  let selectedTemplateMode = $state(defaultTemplateMode(runtimeDefinitions[0]))
  let selectedInstanceId = $state<number | null>(
    selectedRuntimeInstanceId ?? runtimeInstances[0]?.id ?? null,
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

  const selectedRuntimeDefinitionTemplates = $derived(
    selectedRuntimeDefinition?.config_schema?.templates ?? [],
  )

  const selectedRuntimeTemplate = $derived(
    selectedRuntimeDefinitionTemplates.find(
      (template) => template.mode === selectedTemplateMode,
    ) ?? selectedRuntimeDefinitionTemplates[0],
  )

  const selectedInstance = $derived(
    runtimeInstances.find(
      (runtimeInstance) => runtimeInstance.id === selectedInstanceId,
    ) ?? runtimeInstances[0],
  )

  const selectedRuntimeEnvironmentVariables = $derived(
    selectedInstance?.environment_variables ?? [],
  )

  const configTemplate = $derived(
    JSON.stringify(
      {
        template_mode: selectedTemplateMode,
        container_image:
          selectedRuntimeTemplate?.container_image ??
          selectedRuntimeDefinition?.container_image ??
          "",
        command:
          selectedRuntimeTemplate?.default_command ??
          selectedRuntimeDefinition?.default_command ??
          "",
        ...(selectedTemplateMode === "host_binary"
          ? { host_binary_path: "" }
          : {}),
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

  function defaultTemplateMode(runtimeDefinition?: RuntimeDefinition) {
    return (
      runtimeDefinition?.config_schema?.default_template_mode ??
      runtimeDefinition?.config_schema?.templates?.[0]?.mode ??
      "managed_image"
    )
  }

  function changeRuntimeDefinition(event: Event) {
    const runtimeDefinitionId = (event.currentTarget as HTMLSelectElement).value
    selectedRuntimeDefinitionId = runtimeDefinitionId

    const runtimeDefinition = runtimeDefinitions.find(
      (candidate) => candidate.id.toString() === runtimeDefinitionId,
    )
    selectedTemplateMode = defaultTemplateMode(runtimeDefinition)
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
                  onchange={changeRuntimeDefinition}
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

              {#if selectedRuntimeDefinitionTemplates.length > 0}
                <div class="grid gap-2">
                  <Label for="template_mode">Install mode</Label>
                  <select
                    id="template_mode"
                    bind:value={selectedTemplateMode}
                    class="border-input bg-background ring-offset-background focus-visible:ring-ring h-9 rounded-md border px-3 text-sm focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none"
                  >
                    {#each selectedRuntimeDefinitionTemplates as template (template.mode)}
                      <option value={template.mode}>{template.name}</option>
                    {/each}
                  </select>
                  {#if selectedRuntimeTemplate?.description}
                    <p class="text-muted-foreground text-xs">
                      {selectedRuntimeTemplate.description}
                    </p>
                  {/if}
                </div>
              {/if}

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

              <section class="border-border mt-5 rounded-lg border">
                <div class="border-border border-b p-3">
                  <HeadingSmall
                    title="Agent run"
                    description="Execute a command inside the selected Compose service."
                  />
                </div>
                <div class="space-y-3 p-3">
                  <Form
                    method="post"
                    action={workspaceRuntimeInstanceAgentRunsPath(
                      workspace.id,
                      selectedInstance.id,
                    )}
                    class="grid gap-3"
                  >
                    {#snippet children({
                      errors,
                      processing,
                    }: FormComponentSlotProps)}
                      <div class="grid gap-2">
                        <Label for="agent-command">Command</Label>
                        <Input
                          id="agent-command"
                          name="command"
                          placeholder="echo ready"
                          autocomplete="off"
                          required
                        />
                        <InputError messages={errors.command} />
                      </div>
                      <div class="grid gap-2">
                        <Label for="agent-prompt">Prompt</Label>
                        <textarea
                          id="agent-prompt"
                          name="prompt"
                          rows="3"
                          class="border-input bg-background ring-offset-background focus-visible:ring-ring rounded-md border px-3 py-2 text-sm focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none"
                          placeholder="Optional context for this run"
                        ></textarea>
                      </div>
                      <Button type="submit" disabled={processing}>
                        <Play class="size-4" />
                        Run
                      </Button>
                    {/snippet}
                  </Form>

                  {#if selectedInstance.recent_agent_runs.length > 0}
                    <div class="divide-border divide-y rounded-md border">
                      {#each selectedInstance.recent_agent_runs as run (run.id)}
                        <div class="grid gap-1 p-2">
                          <div class="flex items-center justify-between gap-3">
                            <p class="truncate font-mono text-xs">
                              {run.command}
                            </p>
                            <Badge variant="outline">{run.status}</Badge>
                          </div>
                          {#if run.status_message}
                            <p class="text-muted-foreground text-xs">
                              {run.status_message}
                            </p>
                          {/if}
                          {#if run.output}
                            <pre
                              class="max-h-32 overflow-auto rounded bg-black p-2 text-xs whitespace-pre-wrap text-white">{run.output}</pre>
                          {/if}
                        </div>
                      {/each}
                    </div>
                  {/if}
                </div>
              </section>

              <div class="mt-5 grid gap-4 2xl:grid-cols-2">
                <section class="border-border rounded-lg border">
                  <div class="border-border border-b p-3">
                    <HeadingSmall
                      title="System env"
                      description="Applies before runtime overrides."
                    />
                  </div>

                  <div class="space-y-3 p-3">
                    <Form
                      method="post"
                      action={workspaceEnvironmentVariablesPath(workspace.id)}
                      class="grid gap-2 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto_auto]"
                    >
                      {#snippet children({
                        errors,
                        processing,
                      }: FormComponentSlotProps)}
                        <input
                          type="hidden"
                          name="return_runtime_instance_id"
                          value={selectedInstance?.id ?? ""}
                        />
                        <Input
                          name="key"
                          placeholder="KEY"
                          aria-label="System environment variable key"
                          autocomplete="off"
                          required
                        />
                        <Input
                          name="value"
                          placeholder="Value"
                          aria-label="System environment variable value"
                          autocomplete="off"
                          required
                        />
                        <label
                          class="text-muted-foreground flex h-9 items-center gap-2 text-sm"
                        >
                          <input type="hidden" name="sensitive" value="0" />
                          <input
                            type="checkbox"
                            name="sensitive"
                            value="1"
                            class="size-4"
                          />
                          Secret
                        </label>
                        <Button type="submit" disabled={processing}>
                          <Save class="size-4" />
                          Add
                        </Button>
                        <InputError messages={errors.key} />
                        <InputError messages={errors.value} />
                      {/snippet}
                    </Form>

                    {#if systemEnvironmentVariables.length === 0}
                      <p class="text-muted-foreground text-sm">
                        No system variables.
                      </p>
                    {:else}
                      <div class="divide-border divide-y rounded-md border">
                        {#each systemEnvironmentVariables as variable (variable.id)}
                          <div class="grid gap-2 p-2">
                            <Form
                              method="patch"
                              action={workspaceEnvironmentVariablePath(
                                workspace.id,
                                variable.id,
                              )}
                              class="grid gap-2 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto_auto]"
                            >
                              {#snippet children({
                                processing,
                              }: FormComponentSlotProps)}
                                <input
                                  type="hidden"
                                  name="return_runtime_instance_id"
                                  value={selectedInstance?.id ?? ""}
                                />
                                <Input
                                  name="key"
                                  value={variable.key}
                                  aria-label="System environment variable key"
                                  autocomplete="off"
                                  required
                                />
                                <Input
                                  name="value"
                                  value={variable.sensitive
                                    ? ""
                                    : variable.value}
                                  placeholder={variable.sensitive
                                    ? variable.value
                                    : "Value"}
                                  type={variable.sensitive
                                    ? "password"
                                    : "text"}
                                  aria-label="System environment variable value"
                                  autocomplete="off"
                                />
                                <label
                                  class="text-muted-foreground flex h-9 items-center gap-2 text-sm"
                                >
                                  <input
                                    type="hidden"
                                    name="sensitive"
                                    value="0"
                                  />
                                  <input
                                    type="checkbox"
                                    name="sensitive"
                                    value="1"
                                    checked={variable.sensitive}
                                    class="size-4"
                                  />
                                  Secret
                                </label>
                                <Button
                                  type="submit"
                                  variant="outline"
                                  disabled={processing}
                                >
                                  <Save class="size-4" />
                                  Save
                                </Button>
                              {/snippet}
                            </Form>

                            <div class="flex justify-end gap-2">
                              <Form
                                method="patch"
                                action={workspaceEnvironmentVariablePath(
                                  workspace.id,
                                  variable.id,
                                )}
                              >
                                {#snippet children({
                                  processing,
                                }: FormComponentSlotProps)}
                                  <input
                                    type="hidden"
                                    name="return_runtime_instance_id"
                                    value={selectedInstance?.id ?? ""}
                                  />
                                  <input
                                    type="hidden"
                                    name="enabled"
                                    value={variable.enabled ? "0" : "1"}
                                  />
                                  <Button
                                    type="submit"
                                    size="sm"
                                    variant="ghost"
                                    disabled={processing}
                                  >
                                    <Power class="size-4" />
                                    {variable.enabled ? "Disable" : "Enable"}
                                  </Button>
                                {/snippet}
                              </Form>

                              <Form
                                method="delete"
                                action={workspaceEnvironmentVariablePath(
                                  workspace.id,
                                  variable.id,
                                )}
                              >
                                {#snippet children({
                                  processing,
                                }: FormComponentSlotProps)}
                                  <input
                                    type="hidden"
                                    name="return_runtime_instance_id"
                                    value={selectedInstance?.id ?? ""}
                                  />
                                  <Button
                                    type="submit"
                                    size="sm"
                                    variant="ghost"
                                    disabled={processing}
                                  >
                                    <Trash2 class="size-4" />
                                    Delete
                                  </Button>
                                {/snippet}
                              </Form>
                            </div>
                          </div>
                        {/each}
                      </div>
                    {/if}
                  </div>
                </section>

                <section class="border-border rounded-lg border">
                  <div class="border-border border-b p-3">
                    <HeadingSmall
                      title="Runtime env"
                      description="Overrides for the selected runtime."
                    />
                  </div>

                  <div class="space-y-3 p-3">
                    <Form
                      method="post"
                      action={workspaceRuntimeInstanceEnvironmentVariablesPath(
                        workspace.id,
                        selectedInstance.id,
                      )}
                      class="grid gap-2 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto_auto]"
                    >
                      {#snippet children({
                        errors,
                        processing,
                      }: FormComponentSlotProps)}
                        <Input
                          name="key"
                          placeholder="KEY"
                          aria-label="Runtime environment variable key"
                          autocomplete="off"
                          required
                        />
                        <Input
                          name="value"
                          placeholder="Value"
                          aria-label="Runtime environment variable value"
                          autocomplete="off"
                          required
                        />
                        <label
                          class="text-muted-foreground flex h-9 items-center gap-2 text-sm"
                        >
                          <input type="hidden" name="sensitive" value="0" />
                          <input
                            type="checkbox"
                            name="sensitive"
                            value="1"
                            class="size-4"
                          />
                          Secret
                        </label>
                        <Button type="submit" disabled={processing}>
                          <Save class="size-4" />
                          Add
                        </Button>
                        <InputError messages={errors.key} />
                        <InputError messages={errors.value} />
                      {/snippet}
                    </Form>

                    {#if selectedRuntimeEnvironmentVariables.length === 0}
                      <p class="text-muted-foreground text-sm">
                        No runtime overrides.
                      </p>
                    {:else}
                      <div class="divide-border divide-y rounded-md border">
                        {#each selectedRuntimeEnvironmentVariables as variable (variable.id)}
                          <div class="grid gap-2 p-2">
                            <Form
                              method="patch"
                              action={workspaceRuntimeInstanceEnvironmentVariablePath(
                                workspace.id,
                                selectedInstance.id,
                                variable.id,
                              )}
                              class="grid gap-2 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto_auto]"
                            >
                              {#snippet children({
                                processing,
                              }: FormComponentSlotProps)}
                                <Input
                                  name="key"
                                  value={variable.key}
                                  aria-label="Runtime environment variable key"
                                  autocomplete="off"
                                  required
                                />
                                <Input
                                  name="value"
                                  value={variable.sensitive
                                    ? ""
                                    : variable.value}
                                  placeholder={variable.sensitive
                                    ? variable.value
                                    : "Value"}
                                  type={variable.sensitive
                                    ? "password"
                                    : "text"}
                                  aria-label="Runtime environment variable value"
                                  autocomplete="off"
                                />
                                <label
                                  class="text-muted-foreground flex h-9 items-center gap-2 text-sm"
                                >
                                  <input
                                    type="hidden"
                                    name="sensitive"
                                    value="0"
                                  />
                                  <input
                                    type="checkbox"
                                    name="sensitive"
                                    value="1"
                                    checked={variable.sensitive}
                                    class="size-4"
                                  />
                                  Secret
                                </label>
                                <Button
                                  type="submit"
                                  variant="outline"
                                  disabled={processing}
                                >
                                  <Save class="size-4" />
                                  Save
                                </Button>
                              {/snippet}
                            </Form>

                            <div class="flex justify-end gap-2">
                              <Form
                                method="patch"
                                action={workspaceRuntimeInstanceEnvironmentVariablePath(
                                  workspace.id,
                                  selectedInstance.id,
                                  variable.id,
                                )}
                              >
                                {#snippet children({
                                  processing,
                                }: FormComponentSlotProps)}
                                  <input
                                    type="hidden"
                                    name="enabled"
                                    value={variable.enabled ? "0" : "1"}
                                  />
                                  <Button
                                    type="submit"
                                    size="sm"
                                    variant="ghost"
                                    disabled={processing}
                                  >
                                    <Power class="size-4" />
                                    {variable.enabled ? "Disable" : "Enable"}
                                  </Button>
                                {/snippet}
                              </Form>

                              <Form
                                method="delete"
                                action={workspaceRuntimeInstanceEnvironmentVariablePath(
                                  workspace.id,
                                  selectedInstance.id,
                                  variable.id,
                                )}
                              >
                                {#snippet children({
                                  processing,
                                }: FormComponentSlotProps)}
                                  <Button
                                    type="submit"
                                    size="sm"
                                    variant="ghost"
                                    disabled={processing}
                                  >
                                    <Trash2 class="size-4" />
                                    Delete
                                  </Button>
                                {/snippet}
                              </Form>
                            </div>
                          </div>
                        {/each}
                      </div>
                    {/if}
                  </div>
                </section>
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
