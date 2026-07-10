<script lang="ts">
  import { Link } from "@inertiajs/svelte"
  import { ChevronLeft, ChevronRight, Clock, FileText, Folder, Terminal } from "@lucide/svelte"

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
    thread_source?: string
    path: string
    counts?: SessionCounts
    parse_error_count?: number
    current_repo?: boolean
  }

  interface SourceMetadata {
    root_path: string
    scanned_count: number
    parsed_count?: number
    unreadable_count: number
    parse_errors: Array<{ path: string; line: number; message: string }>
    cache?: {
      hits: number
      misses: number
    }
  }

  interface Pagination {
    page: number
    per_page: number
    total_count: number
    total_pages: number
    has_previous_page: boolean
    has_next_page: boolean
  }

  interface Props {
    sessions: CodexSession[]
    source: SourceMetadata
    pagination: Pagination
  }

  let { sessions, source, pagination }: Props = $props()

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Agents",
      href: agentsPath(),
    },
    {
      title: "Sessions",
      href: codexSessionsPath(),
    },
  ]

  function formatDateTime(value?: string) {
    if (!value) return "Not recorded"

    return new Intl.DateTimeFormat(undefined, {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(value))
  }

  function originLabel(session: CodexSession) {
    return session.originator || session.source || session.thread_source || "Codex"
  }

  function countLabel(session: CodexSession) {
    const counts = session.counts ?? {}
    const messages =
      (counts.user_messages ?? 0) + (counts.assistant_messages ?? 0)
    const tools = (counts.tool_calls ?? 0) + (counts.tool_outputs ?? 0)

    return `${messages.toLocaleString()} messages, ${tools.toLocaleString()} tools`
  }

  function pagePath(page: number) {
    return codexSessionsPath({
      page,
      per_page: pagination.per_page,
    })
  }
</script>

<svelte:head>
  <title>Codex Sessions</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <div class="flex h-full flex-1 flex-col gap-6 p-4">
    <section class="border-border rounded-lg border">
      <div
        class="border-border flex flex-col gap-3 border-b p-4 lg:flex-row lg:items-start lg:justify-between"
      >
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <Terminal class="size-4" />
            <h1 class="text-base font-semibold">Codex Sessions</h1>
          </div>
          <p class="text-muted-foreground mt-1 truncate text-sm">
            {source.root_path}
          </p>
        </div>

        <div class="text-muted-foreground flex flex-wrap gap-3 text-sm">
          <span>{source.scanned_count.toLocaleString()} found</span>
          <span>{(source.parsed_count ?? sessions.length).toLocaleString()} parsed</span>
          <span>{source.unreadable_count.toLocaleString()} unreadable</span>
          <span>{source.parse_errors.length.toLocaleString()} parse errors</span>
          {#if source.cache}
            <span>
              {source.cache.hits.toLocaleString()} cache hits,
              {source.cache.misses.toLocaleString()} misses
            </span>
          {/if}
        </div>
      </div>

      {#if sessions.length > 0}
        <div class="divide-border divide-y">
          {#each sessions as session (session.route_id)}
            <Link
              href={codexSessionPath(session.route_id)}
              class="hover:bg-muted/50 grid gap-4 p-4 transition-colors lg:grid-cols-[minmax(0,1fr)_13rem_11rem]"
            >
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-2">
                  <h2 class="truncate text-sm font-medium">{session.title}</h2>
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
                <div class="text-muted-foreground mt-2 grid gap-1 text-sm">
                  <div class="flex min-w-0 items-center gap-1.5">
                    <Folder class="size-3.5 shrink-0" />
                    <span class="truncate">{session.cwd || "Unknown cwd"}</span>
                  </div>
                  <div class="flex min-w-0 items-center gap-1.5">
                    <FileText class="size-3.5 shrink-0" />
                    <span class="truncate">{session.path}</span>
                  </div>
                </div>
              </div>

              <div class="text-muted-foreground text-sm">
                <div class="text-foreground font-medium">{originLabel(session)}</div>
                <div class="mt-1">{session.cli_version || "Version unknown"}</div>
                <div class="mt-1">{countLabel(session)}</div>
              </div>

              <div class="text-muted-foreground text-sm">
                <div class="flex items-center gap-1.5 text-foreground font-medium">
                  <Clock class="size-3.5" />
                  Updated
                </div>
                <div class="mt-1">{formatDateTime(session.updated_at)}</div>
                <div class="mt-2 text-foreground font-medium">Started</div>
                <div class="mt-1">{formatDateTime(session.started_at)}</div>
              </div>
            </Link>
          {/each}
        </div>

        <div
          class="border-border flex flex-col gap-3 border-t p-4 sm:flex-row sm:items-center sm:justify-between"
        >
          <div class="text-muted-foreground text-sm">
            Page {pagination.page.toLocaleString()} of
            {Math.max(pagination.total_pages, 1).toLocaleString()}
            <span class="ml-2">
              {pagination.total_count.toLocaleString()} sessions
            </span>
          </div>
          <div class="flex items-center gap-2">
            <Button
              href={pagePath(pagination.page - 1)}
              variant="outline"
              size="sm"
              disabled={!pagination.has_previous_page}
            >
              <ChevronLeft class="size-4" />
              Previous
            </Button>
            <Button
              href={pagePath(pagination.page + 1)}
              variant="outline"
              size="sm"
              disabled={!pagination.has_next_page}
            >
              Next
              <ChevronRight class="size-4" />
            </Button>
          </div>
        </div>
      {:else}
        <div class="p-8 text-center">
          <Terminal class="text-muted-foreground mx-auto size-8" />
          <h2 class="mt-3 text-sm font-medium">
            {pagination.total_count > 0 ? "No sessions on this page" : "No sessions found"}
          </h2>
          <p class="text-muted-foreground mx-auto mt-2 max-w-lg text-sm">
            {pagination.total_count > 0
              ? "Use the pagination controls to return to a populated page."
              : "The configured sessions directory does not contain readable Codex JSONL files."}
          </p>
        </div>
        {#if pagination.total_count > 0}
          <div
            class="border-border flex flex-col gap-3 border-t p-4 sm:flex-row sm:items-center sm:justify-between"
          >
            <div class="text-muted-foreground text-sm">
              Page {pagination.page.toLocaleString()} of
              {Math.max(pagination.total_pages, 1).toLocaleString()}
              <span class="ml-2">
                {pagination.total_count.toLocaleString()} sessions
              </span>
            </div>
            <div class="flex items-center gap-2">
              <Button
                href={pagePath(pagination.page - 1)}
                variant="outline"
                size="sm"
                disabled={!pagination.has_previous_page}
              >
                <ChevronLeft class="size-4" />
                Previous
              </Button>
              <Button
                href={pagePath(pagination.page + 1)}
                variant="outline"
                size="sm"
                disabled={!pagination.has_next_page}
              >
                Next
                <ChevronRight class="size-4" />
              </Button>
            </div>
          </div>
        {/if}
      {/if}
    </section>
  </div>
</AppLayout>
