<script setup>
import { ref } from "vue";

const open = ref(false);

const hints = [
  {
    number: "01",
    title: "Pay your card with someone else's money",
    body: "On the dashboard, 'Pay your credit card' lets you pick a 'Pay from account' — but the dropdown only lists accounts you own, so clicking around looks safe. The catch is the constraint lives only in the browser. Intercept the POST to /api/cards/pay in your proxy (Burp/ZAP) and change 'from_account' to another customer's number (5021-0002) before it reaches the server. Does the server re-check that the account is yours? Whose balance drops?",
  },
  {
    number: "02",
    title: "Read another customer's statement",
    body: "The 'Statement' panel loads /api/accounts/<your-account>/transactions. The account number sits right in the URL. Account numbers are short and sequential (5021-0001, 5021-0002, …). Change it — does the server check that the account is yours before handing over the history?",
  },
  {
    number: "03",
    title: "Find the application logs",
    body: "Customers aren't the only users of this app. Look closely at the JavaScript bundle / Vue router (or fuzz the URL space) for routes and API paths that the navigation never links to. One of them serves the raw application logs — and the logs leak more than they should. Does that endpoint check who you are, or just that you're logged in?",
  },
];
</script>

<template>
  <button
    @click="open = true"
    class="fixed bottom-6 right-6 w-12 h-12 rounded-full bg-brand hover:bg-brand-dark text-white font-bold text-lg shadow-lg shadow-black/40 transition flex items-center justify-center z-50"
    title="Show hints"
  >
    ?
  </button>

  <Teleport to="body">
    <div
      v-if="open"
      class="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50 p-4"
      @click.self="open = false"
    >
      <div class="bg-card border border-line rounded-2xl w-full max-w-lg shadow-2xl">
        <div class="flex items-center justify-between px-6 py-5 border-b border-line">
          <div>
            <h2 class="text-text font-semibold text-lg">Exercise Hints</h2>
            <p class="text-sub/70 text-xs mt-0.5">A01 — Broken Access Control</p>
          </div>
          <button
            @click="open = false"
            class="text-sub hover:text-text transition w-8 h-8 flex items-center justify-center rounded-lg hover:bg-white/10"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="p-6 space-y-4">
          <div
            v-for="hint in hints"
            :key="hint.number"
            class="flex gap-4 bg-card2/60 rounded-xl p-4 border border-line"
          >
            <span class="text-brand font-mono font-bold text-sm mt-0.5 shrink-0">{{ hint.number }}</span>
            <div>
              <p class="text-text text-sm font-medium mb-1">{{ hint.title }}</p>
              <p class="text-sub text-sm leading-relaxed">{{ hint.body }}</p>
            </div>
          </div>
        </div>

        <div class="px-6 pb-5">
          <button
            @click="open = false"
            class="w-full bg-brand hover:bg-brand-dark text-white font-semibold py-2.5 rounded-lg transition text-sm"
          >
            Got it
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
