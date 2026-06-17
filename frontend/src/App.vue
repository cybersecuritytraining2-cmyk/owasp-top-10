<script setup>
import { ref, computed } from "vue";
import { RouterView, RouterLink, useRouter, useRoute } from "vue-router";
import HintButton from "@/components/HintButton.vue";
import { logout as apiLogout } from "@/services/api.js";

const router = useRouter();
const route = useRoute();
const name = ref(localStorage.getItem("vs_name") || "");

// keep the displayed name fresh as the route changes
router.afterEach(() => {
  name.value = localStorage.getItem("vs_name") || "";
});

// Touch `route.path` so this recomputes on every navigation (login token lives in
// localStorage, which isn't reactive on its own). Without this, the header never
// re-renders after login and the Sign out button stays hidden until a refresh.
const authed = computed(() => {
  route.path;
  return !!localStorage.getItem("vs_token");
});

async function logout() {
  try {
    await apiLogout();
  } catch {
    /* token may already be gone — ignore */
  }
  localStorage.removeItem("vs_token");
  localStorage.removeItem("vs_name");
  localStorage.removeItem("vs_account");
  router.push("/login");
}
</script>

<template>
  <div class="min-h-screen flex flex-col">
    <header class="border-b border-line bg-slab/90 backdrop-blur sticky top-0 z-40">
      <div class="max-w-5xl mx-auto px-5 h-16 flex items-center justify-between">
        <RouterLink to="/dashboard" class="flex items-center gap-2.5">
          <span class="grid place-items-center w-9 h-9 rounded-lg bg-brand text-white font-bold">VS</span>
          <span class="font-bold text-text text-lg tracking-tight">
            Vault Street <span class="text-brand">Bank</span>
          </span>
        </RouterLink>

        <nav v-if="authed && route.path !== '/login'" class="flex items-center gap-5 text-sm">
          <RouterLink to="/dashboard" class="text-sub hover:text-text transition">Dashboard</RouterLink>
          <span class="text-sub/60 hidden sm:inline">{{ name }}</span>
          <button
            @click="logout"
            class="text-sub hover:text-neg transition border border-line hover:border-neg/50 rounded-lg px-3 py-1.5"
          >
            Sign out
          </button>
        </nav>
      </div>
    </header>

    <main class="flex-1 w-full">
      <RouterView />
    </main>

    <footer class="border-t border-line mt-12">
      <div class="max-w-5xl mx-auto px-5 py-8 text-center text-sub/60 text-sm">
        <p>Vault Street Bank · Member FDIC · Routing 021000021</p>
        <p class="mt-1 text-sub/40">A deliberately vulnerable training application. Do not deploy to the internet.</p>
      </div>
    </footer>

    <HintButton />
  </div>
</template>
