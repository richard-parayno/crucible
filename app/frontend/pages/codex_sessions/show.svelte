<script lang="ts">
  import { router } from "@inertiajs/svelte"
  import { ArrowLeft, Clock, Code2, MessageSquare, Terminal } from "@lucide/svelte"

  import { Badge } from "@/components/ui/badge"
  import { Button } from "@/components/ui/button"
  import AppLayout from "@/layouts/app-layout.svelte"
  import { agentsPath, codexSessionPath, codexSessionsPath } from "@/routes"
  import type { BreadcrumbItem } from "@/types"

  interface SessionCounts {
    records?: number
    turns?: number
    user_messages?: number
    assistant_messages?: number
    agent_statuses?: number
    tool_calls?: number
    tool_outputs?: number
  }

  interface CodexSession {
    id: string
    route_id: string
    title: string
    cwd?: string
    started_at?: string
    updated_at?: string
    cli_version?: string
    source?: string
    originator?: string
    path: string
    counts?: SessionCounts
    current_repo?: boolean
    parse_error_count?: number
  }

  interface TimelineItem {
    kind: string
    timestamp?: string
    line_number?: number
    role?: string
    event_type?: string
    text?: string
    call_id?: string
    name?: string
    status?: string
    arguments?: unknown
    output?: unknown
    truncated?: boolean
  }

  interface Props {
    session: CodexSession
    timeline: TimelineItem[]
    timeline_page: TimelinePage
  }

  interface TimelinePage {
    offset: number
    limit: number
    returned_count: number
    total_displayable: number
    has_next_page: boolean
  }

  let { session, timeline, timeline_page }: Props = $props()
  let visibleTimeline = $state<TimelineItem[]>([])
  let currentTimelinePage = $state<TimelinePage>({
    offset: 0,
    limit: 100,
    returned_count: 0,
    total_displayable: 0,
    has_next_page: false,
  })
  let loadingMore = $state(false)
  let loadedRouteId = $state<string | null>(null)

  $effect(() => {
    if (loadedRouteId !== session.route_id) {
      visibleTimeline = timeline
      currentTimelinePage = timeline_page
      loadedRouteId = session.route_id
    }
  })

  let breadcrumbs: BreadcrumbItem[] = $derived([
    {
      title: "Agents",
      href: agentsPath(),
    },
    {
      title: "Sessions",
      href: codexSessionsPath(),
    },
    {
      title: session.title,
      href: "#",
    },
  ])

  function formatDateTime(value?: string) {
    if (!value) return "Not recorded"

    return new Intl.DateTimeFormat(undefined, {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(value))
  }

  function itemIcon(kind: string) {
    if (kind.includes("message")) return MessageSquare
    if (kind.includes("tool")) return Code2

    return Terminal
  }

  function itemLabel(item: TimelineItem) {
    if (item.kind === "user_message") return "User"
    if (item.kind === "assistant_message") return "Assistant"
    if (item.kind === "agent_status") return item.event_type || "Agent status"
    if (item.kind === "tool_call") return item.name || "Tool call"
    if (item.kind === "tool_output") return "Tool output"

    return item.kind
  }

  function renderValue(value: unknown) {
    if (value === null || value === undefined || value === "") return ""
    if (typeof value === "string") return value

    return JSON.stringify(value, null, 2)
  }

  function timelineText(item: TimelineItem) {
    return item.text || renderValue(item.arguments) || renderValue(item.output)
  }

  function loadMoreTimeline() {
    if (loadingMore || !currentTimelinePage.has_next_page) return

    loadingMore = true
    router.get(
      codexSessionPath(session.route_id, {
        timeline_offset:
          currentTimelinePage.offset + currentTimelinePage.returned_count,
        timeline_limit: currentTimelinePage.limit,
      }),
      {},
      {
        preserveScroll: true,
        preserveState: true,
        only: ["timeline", "timeline_page"],
        onSuccess: (page) => {
          const props = page.props as Partial<Props>
          visibleTimeline = [...visibleTimeline, ...(props.timeline ?? [])]
          currentTimelinePage = props.timeline_page ?? currentTimelinePage
        },
        onFinish: () => {
          loadingMore = false
        },
      }
    )
  }
</script>

<svelte:head>
  <title>{session.title}</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <div class="flex h-full flex-1 flex-col gap-6 p-4">
    <div>
      <Button href={codexSessionsPath()} variant="ghost" size="sm">
        <ArrowLeft class="size-4" />
        Sessions
      </Button>
    </div>

    <section class="border-border rounded-lg border">
      <div class="border-border border-b p-4">
        <div class="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <h1 class="truncate text-base font-semibold">{session.title}</h1>
              {#if session.current_repo}
                <Badge class="border-emerald-200 bg-emerald-50 text-emerald-700">
                  Current repo
                </Badge>
              {/if}
              {#if session.parse_error_count}
                <Badge class="border-amber-200 bg-amber-50 text-amber-700">
                  Parse warnings
                </Badge>
              {/if}
            </div>
            <p class="text-muted-foreground mt-2 truncate text-sm">
              {session.cwd || "Unknown cwd"}
            </p>
            <p class="text-muted-foreground mt-1 truncate text-sm">
              {session.path}
            </p>
          </div>

          <div class="text-muted-foreground grid gap-1 text-sm">
            <div class="flex items-center gap-1.5 text-foreground font-medium">
              <Clock class="size-3.5" />
              {formatDateTime(session.updated_at)}
            </div>
            <div>{session.cli_version || "Version unknown"}</div>
            <div>{session.originator || session.source || "Codex"}</div>
          </div>
        </div>
      </div>

      <div class="grid gap-3 p-4 sm:grid-cols-2 lg:grid-cols-5">
        <div class="rounded-md border p-3">
          <div class="text-muted-foreground text-xs">Records</div>
          <div class="mt-1 text-lg font-semibold">
            {(session.counts?.records ?? 0).toLocaleString()}
          </div>
        </div>
        <div class="rounded-md border p-3">
          <div class="text-muted-foreground text-xs">Turns</div>
          <div class="mt-1 text-lg font-semibold">
            {(session.counts?.turns ?? 0).toLocaleString()}
          </div>
        </div>
        <div class="rounded-md border p-3">
          <div class="text-muted-foreground text-xs">Messages</div>
          <div class="mt-1 text-lg font-semibold">
            {(
              (session.counts?.user_messages ?? 0) +
              (session.counts?.assistant_messages ?? 0)
            ).toLocaleString()}
          </div>
        </div>
        <div class="rounded-md border p-3">
          <div class="text-muted-foreground text-xs">Tool Items</div>
          <div class="mt-1 text-lg font-semibold">
            {(
              (session.counts?.tool_calls ?? 0) +
              (session.counts?.tool_outputs ?? 0)
            ).toLocaleString()}
          </div>
        </div>
        <div class="rounded-md border p-3">
          <div class="text-muted-foreground text-xs">Warnings</div>
          <div class="mt-1 text-lg font-semibold">
            {(session.parse_error_count ?? 0).toLocaleString()}
          </div>
        </div>
      </div>
    </section>

    <section class="border-border rounded-lg border">
      <div class="border-border border-b p-4">
        <h2 class="text-base font-semibold">Timeline</h2>
      </div>

      {#if visibleTimeline.length > 0}
        <div class="divide-border divide-y">
          {#each visibleTimeline as item, index (`${item.kind}-${item.line_number}-${index}`)}
            {@const Icon = itemIcon(item.kind)}
            <article class="grid gap-3 p-4 lg:grid-cols-[11rem_minmax(0,1fr)]">
              <div class="text-muted-foreground text-sm">
                <div class="flex items-center gap-2 text-foreground font-medium">
                  <Icon class="size-4" />
                  <span>{itemLabel(item)}</span>
                </div>
                <div class="mt-2">{formatDateTime(item.timestamp)}</div>
                {#if item.line_number}
                  <div class="mt-1">Line {item.line_number}</div>
                {/if}
                {#if item.truncated}
                  <Badge class="mt-2 border-amber-200 bg-amber-50 text-amber-700">
                    Truncated
                  </Badge>
                {/if}
              </div>

              <pre
                class="bg-muted/40 text-foreground min-w-0 overflow-x-auto whitespace-pre-wrap rounded-md p-3 text-sm leading-6"
              >{timelineText(item)}</pre>
            </article>
          {/each}
        </div>
        <div class="border-border flex flex-col gap-3 border-t p-4 sm:flex-row sm:items-center sm:justify-between">
          <div class="text-muted-foreground text-sm">
            Showing {visibleTimeline.length.toLocaleString()} of
            {currentTimelinePage.total_displayable.toLocaleString()} timeline items
          </div>
          <Button
            variant="outline"
            size="sm"
            disabled={!currentTimelinePage.has_next_page || loadingMore}
            onclick={loadMoreTimeline}
          >
            {loadingMore ? "Loading" : "Load more"}
          </Button>
        </div>
      {:else}
        <div class="p-8 text-center">
          <Terminal class="text-muted-foreground mx-auto size-8" />
          <h2 class="mt-3 text-sm font-medium">No displayable timeline items</h2>
        </div>
      {/if}
    </section>
  </div>
</AppLayout>
