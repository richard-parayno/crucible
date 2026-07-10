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
  }

  interface WorkspaceSummary {
    id: number
  }

  interface Props {
    workspace: WorkspaceSummary
    runtime_definitions: RuntimeDefinition[]
  }

  let { workspace, runtime_definitions: runtimeDefinitions }: Props = $props()

  let selectedRuntimeDefinitionId = $state(
    runtimeDefinitions[0]?.id?.toString() ?? "",
  )
  let selectedTemplateMode = $state(defaultTemplateMode(runtimeDefinitions[0]))

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Add Agent",
      href: newAgentPath(),
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

    <section class="border-border max-w-2xl rounded-lg border p-4">
      <HeadingSmall
        title="Agent template"
        description="Choose the agent runtime and install mode."
      />

      <Form method="post" action={agentsPath()} class="mt-5 space-y-4">
        {#snippet children({ errors, processing }: FormComponentSlotProps)}
          <input type="hidden" name="workspace_id" value={workspace.id} />

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
              placeholder={selectedRuntimeDefinition?.name ?? "Agent"}
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

          <div class="flex flex-wrap gap-2">
            <Badge variant="outline">
              {selectedRuntimeDefinition?.name ?? "Agent"}
            </Badge>
            <Badge variant="outline">{selectedTemplateMode}</Badge>
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

          <Button type="submit" disabled={processing}>
            <Bot class="size-4" />
            Add and start agent
          </Button>
        {/snippet}
      </Form>
    </section>
  </div>
</AppLayout>
