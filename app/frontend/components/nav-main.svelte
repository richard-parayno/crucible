<script lang="ts">
  import { Link, page } from "@inertiajs/svelte"
  import { ChevronRight } from "@lucide/svelte"

  import * as Sidebar from "@/components/ui/sidebar"
  import type { NavItem } from "@/types"

  interface Props {
    items: NavItem[]
  }

  let { items }: Props = $props()

  let openItems = $state<Record<string, boolean>>({})

  const isItemActive = (item: NavItem) =>
    item.href === page.url ||
    Boolean(item.items?.some((child) => child.href === page.url))

  const isItemOpen = (item: NavItem) => openItems[item.title] ?? isItemActive(item)

  const toggleItem = (item: NavItem) => {
    openItems[item.title] = !isItemOpen(item)
  }
</script>

<Sidebar.Group class="px-2 py-0">
  <Sidebar.GroupLabel>Platform</Sidebar.GroupLabel>
  <Sidebar.Menu>
    {#each items as item (item.title)}
      <Sidebar.MenuItem>
        {#if item.items?.length}
          <Sidebar.MenuButton
            isActive={isItemActive(item)}
            tooltipContent={item.title}
            aria-expanded={isItemOpen(item)}
            onclick={() => toggleItem(item)}
          >
            {#snippet child({ props })}
              <button type="button" {...props}>
                {#if item.icon}
                  <item.icon />
                {/if}
                <span>{item.title}</span>
                <ChevronRight
                  class={isItemOpen(item)
                    ? "ml-auto rotate-90 transition-transform"
                    : "ml-auto transition-transform"}
                />
              </button>
            {/snippet}
          </Sidebar.MenuButton>

          {#if isItemOpen(item)}
            <Sidebar.MenuSub>
              {#each item.items as childItem (childItem.title)}
                <Sidebar.MenuSubItem>
                  <Sidebar.MenuSubButton isActive={childItem.href === page.url}>
                    {#snippet child({ props })}
                      <Link href={childItem.href} {...props}>
                        <span>{childItem.title}</span>
                      </Link>
                    {/snippet}
                  </Sidebar.MenuSubButton>
                </Sidebar.MenuSubItem>
              {/each}
            </Sidebar.MenuSub>
          {/if}
        {:else}
          <Sidebar.MenuButton
            isActive={item.href === page.url}
            tooltipContent={item.title}
          >
            {#snippet child({ props })}
              <Link href={item.href} {...props}>
                {#if item.icon}
                  <item.icon />
                {/if}
                <span>{item.title}</span>
              </Link>
            {/snippet}
          </Sidebar.MenuButton>
        {/if}
      </Sidebar.MenuItem>
    {/each}
  </Sidebar.Menu>
</Sidebar.Group>
