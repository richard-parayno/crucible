<script lang="ts">
  import { page } from "@inertiajs/svelte"
  import { inertia } from "@inertiajs/svelte"

  import { dashboardPath, signInPath, signUpPath } from "@/routes"
</script>

<svelte:head>
  <link rel="preconnect" href="https://rsms.me/" />
  <link rel="stylesheet" href="https://rsms.me/inter/inter.css" />
</svelte:head>

<div
  class="flex min-h-screen flex-col items-center bg-[#FDFDFC] p-6 text-[#1b1b18] lg:justify-center lg:p-8 dark:bg-[#0a0a0a]"
>
  <header
    class="mb-6 w-full max-w-[335px] text-sm not-has-[nav]:hidden lg:max-w-4xl"
  >
    <nav class="flex items-center justify-end gap-4">
      {#if page.props.auth.user}
        <a
          href={dashboardPath()}
          use:inertia
          class="inline-block rounded-sm border border-[#19140035] px-5 py-1.5 text-sm leading-normal text-[#1b1b18] hover:border-[#1915014a] dark:border-[#3E3E3A] dark:text-[#EDEDEC] dark:hover:border-[#62605b]"
        >
          Dashboard
        </a>
      {:else}
        <a
          href={signInPath()}
          use:inertia
          class="inline-block rounded-sm border border-transparent px-5 py-1.5 text-sm leading-normal text-[#1b1b18] hover:border-[#19140035] dark:text-[#EDEDEC] dark:hover:border-[#3E3E3A]"
        >
          Log in
        </a>
        <a
          href={signUpPath()}
          use:inertia
          class="inline-block rounded-sm border border-[#19140035] px-5 py-1.5 text-sm leading-normal text-[#1b1b18] hover:border-[#1915014a] dark:border-[#3E3E3A] dark:text-[#EDEDEC] dark:hover:border-[#62605b]"
        >
          Register
        </a>
      {/if}
    </nav>
  </header>
  <div
    class="flex w-full items-center justify-center opacity-100 transition-opacity duration-750 lg:grow starting:opacity-0"
  >
    <main class="w-full max-w-[335px] py-24 text-center lg:max-w-4xl">
      <h1 class="text-4xl font-medium tracking-tight dark:text-[#EDEDEC]">
        crucible
      </h1>
      <p class="mt-4 text-base text-[#706f6c] dark:text-[#A1A09A]">
        a simple multiplayer agent workspace
      </p>
    </main>
  </div>
</div>
