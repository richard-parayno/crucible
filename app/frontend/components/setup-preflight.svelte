<script lang="ts">
  import HeadingSmall from "@/components/heading-small.svelte"
  import { Badge } from "@/components/ui/badge"

  type CapabilityState =
    "supported" | "unsupported" | "unknown" | "detected" | string

  interface HostCapability {
    status?: CapabilityState
    supported?: boolean
    path?: string | null
    reason?: string
    total_bytes?: number
    used_bytes?: number
    available_bytes?: number
    capacity?: string
    [key: string]: unknown
  }

  interface RuntimeDefinition {
    kind: string
    name: string
  }

  interface PreflightRow {
    label: string
    status: CapabilityState
    details: string[]
  }

  interface Props {
    hostCapabilities: Record<string, unknown>
    runtimeDefinitions: RuntimeDefinition[]
  }

  let { hostCapabilities, runtimeDefinitions }: Props = $props()

  const containerRows = $derived([
    capabilityRow("Docker", capabilityAt(["container", "docker"])),
    capabilityRow(
      "Docker Compose",
      capabilityAt(["container", "docker_compose"]),
      {
        pathLabel: "Version",
      },
    ),
    capabilityRow(
      "Rootless Docker",
      capabilityAt(["container", "rootless_docker"]),
      {
        showPath: false,
      },
    ),
  ])

  const hostRows = $derived([
    capacityRow("Disk", capabilityAt(["host", "disk"])),
    capacityRow("Memory", capabilityAt(["host", "memory"])),
  ])

  const networkRows = $derived([
    capabilityRow("Tailscale", capabilityAt(["networking", "tailscale"]), {
      extraDetails: tailnetAccessDetails(
        capabilityAt(["networking", "tailscale"]),
      ),
      showPath: false,
    }),
  ])

  const agentRows = $derived(
    agentBinaryRows(hostCapabilities, runtimeDefinitions),
  )

  function capabilityAt(path: string[]): HostCapability {
    let value: unknown = hostCapabilities

    for (const key of path) {
      if (!value || typeof value !== "object") return { status: "unknown" }
      value = (value as Record<string, unknown>)[key]
    }

    if (!value || typeof value !== "object") return { status: "unknown" }

    return value as HostCapability
  }

  function capabilityRow(
    label: string,
    capability: HostCapability,
    options: {
      showPath?: boolean
      pathLabel?: string
      extraDetails?: string[]
    } = {},
  ): PreflightRow {
    const { showPath = true, pathLabel, extraDetails = [] } = options
    const details = [...extraDetails]

    if (showPath && capability.path) {
      details.push(
        pathLabel ? `${pathLabel}: ${capability.path}` : capability.path,
      )
    }

    if (capability.reason) details.push(capability.reason)

    return {
      label,
      status: capability.status ?? "unknown",
      details,
    }
  }

  function capacityRow(
    label: string,
    capability: HostCapability,
  ): PreflightRow {
    const details: string[] = []
    const available = formatBytes(capability.available_bytes)
    const total = formatBytes(capability.total_bytes)

    if (available && total) {
      details.push(`${available} free of ${total}`)
    } else if (total) {
      details.push(`${total} total`)
    }

    if (capability.capacity) details.push(`${capability.capacity} used`)
    if (capability.path) details.push(`Path: ${capability.path}`)
    if (capability.reason) details.push(capability.reason)

    return {
      label,
      status: capability.status ?? "unknown",
      details,
    }
  }

  function agentBinaryRows(
    capabilities: Record<string, unknown>,
    definitions: RuntimeDefinition[],
  ): PreflightRow[] {
    const agentCapabilities = recordAt(capabilities, ["agent_binaries"])
    const definitionNames = new Map(
      definitions.map((definition) => [definition.kind, definition.name]),
    )

    return Object.entries(agentCapabilities).map(([kind, capability]) =>
      capabilityRow(
        definitionNames.get(kind) ?? titleize(kind),
        normalizeCapability(capability),
      ),
    )
  }

  function recordAt(
    source: Record<string, unknown>,
    path: string[],
  ): Record<string, unknown> {
    let value: unknown = source

    for (const key of path) {
      if (!value || typeof value !== "object") return {}
      value = (value as Record<string, unknown>)[key]
    }

    if (!value || typeof value !== "object" || Array.isArray(value)) return {}

    return value as Record<string, unknown>
  }

  function normalizeCapability(value: unknown): HostCapability {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      return { status: "unknown" }
    }

    return value as HostCapability
  }

  function tailnetAccessDetails(capability: HostCapability): string[] {
    const values = [
      firstString(capability, [
        "access_url",
        "tailnet_url",
        "url",
        "web_url",
        "ip",
        "ipv4",
        "tailnet_ip",
        "tailscale_ip",
      ]),
      ...stringList(capability.addresses),
      ...stringList(capability.ips),
    ].filter(Boolean)

    return [...new Set(values)] as string[]
  }

  function firstString(
    record: Record<string, unknown>,
    keys: string[],
  ): string | undefined {
    for (const key of keys) {
      const value = record[key]
      if (typeof value === "string" && value.trim()) return value.trim()
    }
  }

  function stringList(value: unknown): string[] {
    if (!Array.isArray(value)) return []

    return value.filter(
      (item): item is string => typeof item === "string" && item.trim() !== "",
    )
  }

  function formatBytes(value: unknown) {
    if (typeof value !== "number" || !Number.isFinite(value)) return undefined

    const units = ["B", "KiB", "MiB", "GiB", "TiB"]
    let amount = value
    let unitIndex = 0

    while (amount >= 1024 && unitIndex < units.length - 1) {
      amount /= 1024
      unitIndex += 1
    }

    const maximumFractionDigits = amount >= 10 || unitIndex === 0 ? 0 : 1

    return `${amount.toLocaleString(undefined, {
      maximumFractionDigits,
    })} ${units[unitIndex]}`
  }

  function titleize(value: string) {
    return value
      .split(/[_-]/)
      .filter(Boolean)
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(" ")
  }

  function statusTone(status: CapabilityState) {
    if (["supported", "detected"].includes(status)) {
      return "border-emerald-200 bg-emerald-50 text-emerald-700"
    }

    if (status === "unsupported") {
      return "border-red-200 bg-red-50 text-red-700"
    }

    return "border-amber-200 bg-amber-50 text-amber-700"
  }

  function statusLabel(status: CapabilityState) {
    return titleize(status || "unknown")
  }
</script>

{#snippet preflightGroup(title: string, rows: PreflightRow[])}
  <div class="bg-background p-3">
    <h2
      class="text-muted-foreground mb-1 text-xs font-medium tracking-wide uppercase"
    >
      {title}
    </h2>

    {#if rows.length === 0}
      <p class="text-muted-foreground py-2 text-sm">No checks.</p>
    {:else}
      <dl class="divide-border divide-y">
        {#each rows as row (row.label)}
          <div class="grid grid-cols-[minmax(0,1fr)_auto] gap-x-2 gap-y-1 py-2">
            <dt class="min-w-0 truncate text-sm font-medium">{row.label}</dt>
            <dd>
              <Badge variant="outline" class={statusTone(row.status)}>
                {statusLabel(row.status)}
              </Badge>
            </dd>
            {#if row.details.length > 0}
              <dd class="col-span-2 min-w-0 space-y-1">
                {#each row.details as detail (detail)}
                  <p
                    class="text-muted-foreground min-w-0 text-xs leading-5 break-words [overflow-wrap:anywhere]"
                  >
                    {detail}
                  </p>
                {/each}
              </dd>
            {/if}
          </div>
        {/each}
      </dl>
    {/if}
  </div>
{/snippet}

<section class="border-border overflow-hidden rounded-lg border">
  <div class="border-border border-b p-3">
    <HeadingSmall title="Setup preflight" description="Local host checks" />
  </div>

  <div class="bg-border grid gap-px sm:grid-cols-2 xl:grid-cols-4">
    {@render preflightGroup("Container", containerRows)}
    {@render preflightGroup("Host", hostRows)}
    {@render preflightGroup("Network", networkRows)}
    {@render preflightGroup("Agents", agentRows)}
  </div>
</section>
