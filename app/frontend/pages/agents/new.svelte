<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"
  import { Bot } from "@lucide/svelte"

  import HeadingSmall from "@/components/heading-small.svelte"
  import InputError from "@/components/input-error.svelte"
  import { Badge } from "@/components/ui/badge"
  import { Button } from "@/components/ui/button"
  import { Input } from "@/components/ui/input"
  import { Label } from "@/components/ui/label"
  import AppLayout from "@/layouts/app-layout.svelte"
  import { agentsPath, newAgentPath } from "@/routes"
  import type { BreadcrumbItem } from "@/types"

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
    config_mount_path?: string
  }

  interface WorkspaceSummary {
    id: number
  }

  interface Props {
    workspace: WorkspaceSummary
    runtime_definitions: RuntimeDefinition[]
    import_defaults?: ImportDefaults
  }

  interface ImportDefaults {
    runtime_definition_id?: string | number
    kind?: string
    name?: string
    template_mode?: string
    host_binary_path?: string
    command?: string
    working_directory?: string
  }

  let {
    workspace,
    runtime_definitions: runtimeDefinitions,
    import_defaults: importDefaults = {},
  }: Props = $props()

  let selectedRuntimeDefinitionId = $state("")
  let selectedTemplateMode = $state("managed_image")
  let initializedFromImportDefaults = $state(false)

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Add Agent",
      href: newAgentPath(),
    },
  ]

  const envPlaceholder = "OPENAI_API_KEY=...\nANTHROPIC_API_KEY=..."

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

  $effect.pre(() => {
    if (initializedFromImportDefaults) return

    const runtimeDefinition = initialRuntimeDefinition()
    selectedRuntimeDefinitionId = runtimeDefinition?.id?.toString() ?? ""
    selectedTemplateMode =
      importDefaults.template_mode ?? defaultTemplateMode(runtimeDefinition)
    initializedFromImportDefaults = true
  })

  const selectedContainerImage = $derived(
    selectedRuntimeTemplate?.container_image ??
      selectedRuntimeDefinition?.container_image ??
      "",
  )

  const selectedCommand = $derived(
    importDefaults.command ??
      selectedRuntimeTemplate?.default_command ??
      selectedRuntimeDefinition?.default_command ??
      "",
  )

  const selectedConfigMountPath = $derived(
    selectedRuntimeTemplate?.config_mount_path ??
      "/root/.config/crucible-agent",
  )

  function initialRuntimeDefinition() {
    return (
      runtimeDefinitions.find(
        (runtimeDefinition) =>
          runtimeDefinition.id.toString() ===
            importDefaults.runtime_definition_id?.toString() ||
          runtimeDefinition.kind === importDefaults.kind,
      ) ?? runtimeDefinitions[0]
    )
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
</script>

<svelte:head>
  <title>Add Agent</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <div class="flex h-full flex-col gap-6 p-4">
    <section class="flex items-start justify-between gap-4">
      <div>
        <div class="flex items-center gap-2">
          <Bot class="size-5" />
          <h1 class="text-2xl font-semibold tracking-tight">Add Agent</h1>
        </div>
        <p class="text-muted-foreground mt-1 max-w-2xl text-sm">
          Add a Compose-managed agent.
        </p>
      </div>
    </section>

    <section class="border-border max-w-4xl rounded-lg border p-4">
      <HeadingSmall
        title="Agent template"
        description="Choose the agent runtime and install mode."
      />

      <Form method="post" action={agentsPath()} class="mt-5 space-y-5">
        {#snippet children({ errors, processing }: FormComponentSlotProps)}
          <input type="hidden" name="workspace_id" value={workspace.id} />
          {#if importDefaults.working_directory}
            <input
              type="hidden"
              name="working_directory"
              value={importDefaults.working_directory}
            />
          {/if}

          <div class="grid gap-2">
            <Label for="runtime_definition_id">Agent</Label>
            <select
              id="runtime_definition_id"
              name="runtime_definition_id"
              bind:value={selectedRuntimeDefinitionId}
              onchange={changeRuntimeDefinition}
              class="border-input bg-background ring-offset-background focus-visible:ring-ring h-9 rounded-md border px-3 text-sm focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none"
            >
              {#each runtimeDefinitions as runtimeDefinition (runtimeDefinition.id)}
                <option value={runtimeDefinition.id.toString()}>
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
              value={importDefaults.name ?? ""}
              placeholder={selectedRuntimeDefinition?.name ?? "Agent"}
            />
            <InputError messages={errors.name} />
          </div>

          {#if selectedRuntimeDefinitionTemplates.length > 0}
            <div class="grid gap-2">
              <Label for="template_mode">Install mode</Label>
              <select
                id="template_mode"
                name="template_mode"
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

          <div class="flex flex-wrap gap-2">
            <Badge variant="outline">
              {selectedRuntimeDefinition?.name ?? "Agent"}
            </Badge>
            <Badge variant="outline">{selectedTemplateMode}</Badge>
            <Badge variant="outline">docker compose</Badge>
          </div>

          <div
            class="grid gap-4"
            style="grid-template-columns: repeat(auto-fit, minmax(min(18rem, 100%), 1fr));"
          >
            <div class="grid gap-2">
              <Label for="container_image">Container image</Label>
              <Input
                id="container_image"
                name="container_image"
                value={selectedContainerImage}
                placeholder="alpine:latest"
              />
            </div>

            <div class="grid gap-2">
              <Label for="host_binary_path">Host binary path</Label>
              <Input
                id="host_binary_path"
                name="host_binary_path"
                value={importDefaults.host_binary_path ?? ""}
                placeholder="/usr/local/bin/codex"
                disabled={selectedTemplateMode !== "host_binary"}
              />
              {#if selectedTemplateMode === "host_binary"}
                <p class="text-muted-foreground text-xs">
                  The binary is mounted read-only into the Compose service.
                </p>
              {/if}
            </div>
          </div>

          <div class="grid gap-2">
            <Label for="command">Command</Label>
            <textarea
              id="command"
              name="command"
              rows="4"
              class="border-input bg-background ring-offset-background focus-visible:ring-ring min-h-24 rounded-md border px-3 py-2 font-mono text-xs focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none"
              value={selectedCommand}></textarea>
          </div>

          <div
            class="border-border grid gap-4 rounded-md border p-3"
            style="grid-template-columns: repeat(auto-fit, minmax(min(16rem, 100%), 1fr));"
          >
            <input type="hidden" name="config_volume_enabled" value="0" />
            <label class="flex items-center gap-2 text-sm font-medium">
              <input
                type="checkbox"
                name="config_volume_enabled"
                value="1"
                checked
                class="border-input size-4 rounded"
              />
              Config volume
            </label>

            <div class="grid gap-2">
              <Label for="config_mount_path">Mount path</Label>
              <Input
                id="config_mount_path"
                name="config_mount_path"
                value={selectedConfigMountPath}
              />
            </div>

            <div class="grid gap-2">
              <Label for="config_volume_name">Volume name</Label>
              <Input
                id="config_volume_name"
                name="config_volume_name"
                placeholder="Generated per runtime"
              />
            </div>
          </div>

          <div class="grid gap-2">
            <Label for="env_lines">Environment variables</Label>
            <textarea
              id="env_lines"
              name="env_lines"
              rows="5"
              class="border-input bg-background ring-offset-background focus-visible:ring-ring rounded-md border px-3 py-2 font-mono text-xs focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none"
              placeholder={envPlaceholder}></textarea>
            <InputError messages={errors.config} />
          </div>

          <Button type="submit" disabled={processing}>
            <Bot class="size-4" />
            Add and start agent
          </Button>
        {/snippet}
      </Form>
    </section>
  </div>
</AppLayout>
