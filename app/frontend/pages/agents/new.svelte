<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"
  import {
    Bot,
    Box,
    CheckCircle2,
    FileText,
    LinkIcon,
    ShieldCheck,
    Terminal,
  } from "@lucide/svelte"

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
      install_sources?: InstallSource[]
      verified_artifacts?: VerifiedArtifact[]
      trust_level?: string
      verification_summary?: string
      docs_url?: string
      source_url?: string
    }
  }

  interface RuntimeTemplate {
    mode: string
    name: string
    description?: string
    container_image?: string
    default_command?: string
    config_mount_path?: string
    install_sources?: InstallSource[]
    verified_artifacts?: VerifiedArtifact[]
    trust_level?: string
    verification_summary?: string
    docs_url?: string
    source_url?: string
    binary?: string
  }

  type InstallSource =
    | string
    | {
        label?: string
        name?: string
        url?: string
        docs_url?: string
        source_url?: string
        command?: string
      }

  type VerifiedArtifact =
    | string
    | {
        kind?: string
        name?: string
        url?: string
        value?: string
        checksum?: string
        sha256?: string
        version?: string
        available?: boolean
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

  const selectedInstallSources = $derived(
    selectedRuntimeTemplate?.install_sources ??
      selectedRuntimeDefinition?.config_schema?.install_sources ??
      [],
  )

  const selectedVerifiedArtifacts = $derived(
    (
      selectedRuntimeTemplate?.verified_artifacts ??
      selectedRuntimeDefinition?.config_schema?.verified_artifacts ??
      []
    ).filter(hasArtifactValue),
  )

  const selectedTrustLevel = $derived(
    selectedRuntimeTemplate?.trust_level ??
      selectedRuntimeDefinition?.config_schema?.trust_level ??
      "unverified",
  )

  const selectedVerificationSummary = $derived(
    selectedRuntimeTemplate?.verification_summary ??
      selectedRuntimeDefinition?.config_schema?.verification_summary ??
      verificationSummaryFor(selectedTemplateMode, selectedVerifiedArtifacts),
  )

  const selectedDocsUrl = $derived(
    selectedRuntimeTemplate?.docs_url ??
      selectedRuntimeDefinition?.config_schema?.docs_url,
  )

  const selectedSourceUrl = $derived(
    selectedRuntimeTemplate?.source_url ??
      selectedRuntimeDefinition?.config_schema?.source_url,
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
    const runtimeDefinitionId = (event.currentTarget as HTMLInputElement).value
    selectedRuntimeDefinitionId = runtimeDefinitionId

    const runtimeDefinition = runtimeDefinitions.find(
      (candidate) => candidate.id.toString() === runtimeDefinitionId,
    )
    selectedTemplateMode = defaultTemplateMode(runtimeDefinition)
  }

  function trustTone(trustLevel?: string) {
    if (["verified", "pinned", "trusted"].includes(trustLevel ?? "")) {
      return "border-emerald-200 bg-emerald-50 text-emerald-700"
    }

    if (["docs_only", "unverified", "unavailable"].includes(trustLevel ?? "")) {
      return "border-amber-200 bg-amber-50 text-amber-700"
    }

    return "border-border bg-muted text-muted-foreground"
  }

  function titleize(value?: string) {
    if (!value) return "Unknown"

    return value
      .replace(/[_-]+/g, " ")
      .replace(/\b\w/g, (character) => character.toUpperCase())
  }

  function installModeSummary(template: RuntimeTemplate) {
    if (template.mode === "host_binary") {
      return "Import a detected host binary path and mount it read-only into the Compose service."
    }

    if (template.mode === "managed_image") {
      return "Use a Crucible-managed runtime only when a pinned artifact and checksum are available."
    }

    return template.description ?? "Provide runtime config for this template."
  }

  function verificationSummaryFor(
    templateMode: string,
    verifiedArtifacts: VerifiedArtifact[],
  ) {
    if (templateMode === "host_binary") {
      return "Detected host binaries can be imported; Crucible records the path but does not execute upstream install scripts."
    }

    if (verifiedArtifacts.length > 0) {
      return "Pinned artifacts are available for managed install verification."
    }

    return "No pinned artifact or checksum is available, so managed install is not treated as verified."
  }

  function sourceText(source: InstallSource) {
    if (typeof source === "string") return source

    return (
      source.label ??
      source.name ??
      source.url ??
      source.docs_url ??
      source.source_url ??
      source.command ??
      "Install source"
    )
  }

  function artifactText(artifact: VerifiedArtifact) {
    if (typeof artifact === "string") return artifact

    const checksum = artifact.checksum ?? artifact.sha256 ?? artifact.value
    const label =
      artifact.name ??
      artifact.kind ??
      artifact.version ??
      artifact.url ??
      "Artifact"

    return [titleize(label), checksum].filter(Boolean).join(": ")
  }

  function hasArtifactValue(artifact: VerifiedArtifact) {
    if (typeof artifact === "string") return artifact.trim().length > 0
    if (artifact.available === false) return false

    return Boolean(
      artifact.value ??
      artifact.checksum ??
      artifact.sha256 ??
      artifact.name ??
      artifact.version ??
      artifact.url,
    )
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
          Select a supported agent template, choose how it is installed, then
          review the runtime config Crucible will submit.
        </p>
      </div>
    </section>

    <section class="border-border max-w-4xl rounded-lg border p-4">
      <HeadingSmall
        title="Agent template"
        description="Supported templates are selected before runtime config."
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

          <div class="grid gap-3">
            <div class="flex items-center gap-2">
              <Bot class="text-muted-foreground size-4" />
              <Label>Supported agent</Label>
            </div>
            <div class="grid gap-2">
              {#each runtimeDefinitions as runtimeDefinition (runtimeDefinition.id)}
                <label
                  class={[
                    "border-border hover:bg-muted/40 grid cursor-pointer gap-1 rounded-md border p-3 text-sm",
                    selectedRuntimeDefinitionId ===
                    runtimeDefinition.id.toString()
                      ? "border-primary bg-muted/40"
                      : "",
                  ]}
                >
                  <input
                    class="sr-only"
                    type="radio"
                    name="runtime_definition_id"
                    value={runtimeDefinition.id.toString()}
                    checked={selectedRuntimeDefinitionId ===
                      runtimeDefinition.id.toString()}
                    onchange={changeRuntimeDefinition}
                  />
                  <span class="flex items-center justify-between gap-3">
                    <span class="font-medium">{runtimeDefinition.name}</span>
                    {#if selectedRuntimeDefinitionId === runtimeDefinition.id.toString()}
                      <CheckCircle2 class="text-primary size-4 shrink-0" />
                    {/if}
                  </span>
                  <span class="text-muted-foreground text-xs">
                    {runtimeDefinition.description ??
                      `${runtimeDefinition.kind} runtime template`}
                  </span>
                </label>
              {/each}
            </div>
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
            <div class="grid gap-3">
              <div class="flex items-center gap-2">
                <Box class="text-muted-foreground size-4" />
                <Label>Install mode</Label>
              </div>
              <div class="grid gap-2 sm:grid-cols-2">
                {#each selectedRuntimeDefinitionTemplates as template (template.mode)}
                  <label
                    class={[
                      "border-border hover:bg-muted/40 grid cursor-pointer gap-2 rounded-md border p-3 text-sm",
                      selectedTemplateMode === template.mode
                        ? "border-primary bg-muted/40"
                        : "",
                    ]}
                  >
                    <input
                      class="sr-only"
                      type="radio"
                      name="template_mode"
                      value={template.mode}
                      bind:group={selectedTemplateMode}
                    />
                    <span class="flex items-center justify-between gap-3">
                      <span class="font-medium">{template.name}</span>
                      <Badge variant="outline">{template.mode}</Badge>
                    </span>
                    <span class="text-muted-foreground text-xs leading-5">
                      {installModeSummary(template)}
                    </span>
                  </label>
                {/each}
              </div>
            </div>
          {/if}

          <section class="border-border grid gap-3 rounded-md border p-3">
            <div class="flex flex-wrap items-center gap-2">
              <ShieldCheck class="size-4" />
              <h2 class="text-sm font-medium">Provenance and verification</h2>
              <Badge variant="outline" class={trustTone(selectedTrustLevel)}>
                {titleize(selectedTrustLevel)}
              </Badge>
            </div>
            <p class="text-muted-foreground text-sm">
              {selectedVerificationSummary}
            </p>
            <div class="grid gap-3 text-sm sm:grid-cols-2">
              <div>
                <div
                  class="text-muted-foreground text-xs font-medium tracking-wide uppercase"
                >
                  Install sources
                </div>
                {#if selectedInstallSources.length > 0}
                  <ul class="mt-2 space-y-1">
                    {#each selectedInstallSources as source (sourceText(source))}
                      <li class="text-muted-foreground break-words text-xs">
                        {sourceText(source)}
                      </li>
                    {/each}
                  </ul>
                {:else}
                  <p class="text-muted-foreground mt-2 text-xs">
                    Upstream install scripts are documentation only; Crucible
                    does not execute them.
                  </p>
                {/if}
              </div>
              <div>
                <div
                  class="text-muted-foreground text-xs font-medium tracking-wide uppercase"
                >
                  Verified artifacts
                </div>
                {#if selectedVerifiedArtifacts.length > 0}
                  <ul class="mt-2 space-y-1">
                    {#each selectedVerifiedArtifacts as artifact (artifactText(artifact))}
                      <li class="text-muted-foreground break-words text-xs">
                        {artifactText(artifact)}
                      </li>
                    {/each}
                  </ul>
                {:else}
                  <p class="text-muted-foreground mt-2 text-xs">
                    Verified managed install is only safe when a pinned artifact
                    and checksum exist.
                  </p>
                {/if}
              </div>
            </div>
            <div class="flex flex-wrap gap-2">
              {#if selectedDocsUrl}
                <Button href={selectedDocsUrl} variant="outline" size="sm">
                  <FileText class="size-4" />
                  Docs
                </Button>
              {/if}
              {#if selectedSourceUrl}
                <Button href={selectedSourceUrl} variant="outline" size="sm">
                  <LinkIcon class="size-4" />
                  Source
                </Button>
              {/if}
            </div>
          </section>

          <div class="flex flex-wrap gap-2">
            <Badge variant="outline">
              {selectedRuntimeDefinition?.name ?? "Agent"}
            </Badge>
            <Badge variant="outline">{selectedTemplateMode}</Badge>
            <Badge variant="outline">docker compose</Badge>
            {#if importDefaults.host_binary_path}
              <Badge variant="outline">host binary import</Badge>
            {/if}
          </div>

          <div class="grid gap-2">
            <div class="flex items-center gap-2">
              <Terminal class="text-muted-foreground size-4" />
              <Label>Runtime config</Label>
            </div>
            <p class="text-muted-foreground text-xs">
              Detected host binaries can be imported into this form. External
              host process imports keep their binary path, command, and working
              directory defaults.
            </p>
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
