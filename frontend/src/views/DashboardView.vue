<script setup>
import { ref, onMounted, computed } from "vue";
import { useRouter } from "vue-router";
import {
  getMe,
  getTransactions,
  transfer,
  payCard,
  openAccount,
} from "@/services/api.js";

const router = useRouter();
const me = ref(null);
const loading = ref(true);

// statement
const statementAccount = ref("");
const statement = ref(null);
const statementError = ref("");

// transfer form
const transferTo = ref("");
const transferAmount = ref("");
const transferMsg = ref("");
const transferErr = ref("");

// card payment form
const payFrom = ref("");
const payAmount = ref("");
const payMsg = ref("");
const payErr = ref("");

// open-new-account form
const newAccountLabel = ref("");
const openMsg = ref("");
const openWelcome = ref("");
const openErr = ref("");

const money = (n) =>
  new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(n);

const available = computed(() =>
  me.value?.card ? me.value.card.limit - me.value.card.owed : 0
);

onMounted(load);

async function load() {
  loading.value = true;
  try {
    const { data } = await getMe();
    me.value = data;
    statementAccount.value = data.account_number;
    // Default the "pay from" dropdown to the customer's first owned account.
    payFrom.value = data.accounts?.[0]?.number || data.account_number;
    await loadStatement();
  } catch (e) {
    if (e.response?.status === 401) router.push("/login");
  } finally {
    loading.value = false;
  }
}

async function loadStatement() {
  statementError.value = "";
  try {
    const { data } = await getTransactions(statementAccount.value.trim());
    statement.value = data;
  } catch (e) {
    statement.value = null;
    statementError.value = e.response?.data?.error || "Could not load statement.";
  }
}

async function submitTransfer() {
  transferMsg.value = transferErr.value = "";
  try {
    await transfer(transferTo.value.trim(), Number(transferAmount.value));
    transferMsg.value = `Sent ${money(Number(transferAmount.value))} to ${transferTo.value.trim()}.`;
    transferTo.value = transferAmount.value = "";
    await load();
  } catch (e) {
    transferErr.value = e.response?.data?.error || "Transfer failed.";
  }
}

async function submitPay() {
  payMsg.value = payErr.value = "";
  try {
    const { data } = await payCard(payFrom.value.trim(), Number(payAmount.value));
    payMsg.value = `Paid toward your card from ${data.funded_from}. Remaining balance ${money(data.card_owed)}.`;
    payAmount.value = "";
    await load();
  } catch (e) {
    payErr.value = e.response?.data?.error || "Payment failed.";
  }
}

async function submitOpenAccount() {
  openMsg.value = openErr.value = openWelcome.value = "";
  try {
    const { data } = await openAccount(newAccountLabel.value.trim());
    openMsg.value = `Opened ${data.account.label} (${data.account.number}) · ${money(data.account.balance)}.`;
    openWelcome.value = data.welcome;
    newAccountLabel.value = "";
    await load();
  } catch (e) {
    openErr.value = e.response?.data?.error || "Could not open account.";
  }
}
</script>

<template>
  <section class="max-w-5xl mx-auto px-5 py-8">
    <div v-if="loading" class="text-center text-sub py-16">Loading your accounts…</div>

    <div v-else-if="me" class="space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-text">Welcome back, {{ me.name.split(" ")[0] }}</h1>
        <p class="text-sub text-sm mt-1">Here's an overview of your Vault Street accounts.</p>
      </div>

      <!-- Account + card summary -->
      <div class="grid md:grid-cols-2 gap-4">
        <div class="bg-gradient-to-br from-card to-card2 border border-line rounded-2xl p-6">
          <p class="text-sub text-sm">Checking account</p>
          <p class="font-mono text-sub/80 text-sm mt-1">{{ me.account_number }}</p>
          <p class="text-3xl font-bold text-text mt-4">{{ money(me.balance) }}</p>
          <p class="text-pos text-xs mt-1">Available balance</p>
        </div>

        <div v-if="me.card" class="bg-gradient-to-br from-[#1a2748] to-[#101a31] border border-line rounded-2xl p-6">
          <p class="text-sub text-sm">Vault Street Credit Card</p>
          <p class="font-mono text-sub/80 text-sm mt-1 tracking-widest">{{ me.card.number }}</p>
          <p class="text-3xl font-bold text-neg mt-4">{{ money(me.card.owed) }}</p>
          <p class="text-sub text-xs mt-1">
            Current balance · {{ money(available) }} of {{ money(me.card.limit) }} available
          </p>
        </div>
      </div>

      <!-- Actions -->
      <div class="grid md:grid-cols-2 gap-4">
        <!-- Transfer -->
        <form @submit.prevent="submitTransfer" class="bg-card border border-line rounded-2xl p-6 space-y-3">
          <h2 class="text-text font-semibold">Transfer money</h2>
          <p class="text-sub text-xs">Send funds to another Vault Street customer by account number.</p>
          <div>
            <label class="block text-xs text-sub mb-1">Recipient account number</label>
            <input
              v-model="transferTo"
              placeholder="5021-0003"
              class="w-full bg-ink border border-line rounded-lg px-3 py-2 text-text font-mono focus:border-brand outline-none"
            />
          </div>
          <div>
            <label class="block text-xs text-sub mb-1">Amount (USD)</label>
            <input
              v-model="transferAmount"
              type="number"
              step="0.01"
              min="0"
              placeholder="100.00"
              class="w-full bg-ink border border-line rounded-lg px-3 py-2 text-text focus:border-brand outline-none"
            />
          </div>
          <button class="w-full bg-brand hover:bg-brand-dark text-white font-semibold py-2.5 rounded-lg transition">
            Send transfer
          </button>
          <p v-if="transferMsg" class="text-pos text-sm">{{ transferMsg }}</p>
          <p v-if="transferErr" class="text-neg text-sm">{{ transferErr }}</p>
        </form>

        <!-- Pay credit card -->
        <form
          v-if="me.card"
          @submit.prevent="submitPay"
          class="bg-card border border-line rounded-2xl p-6 space-y-3"
        >
          <h2 class="text-text font-semibold">Pay your credit card</h2>
          <p class="text-sub text-xs">Pay down your card balance from one of your accounts.</p>
          <div>
            <label class="block text-xs text-sub mb-1">Pay from account</label>
            <select
              v-model="payFrom"
              class="w-full bg-ink border border-line rounded-lg px-3 py-2 text-text font-mono focus:border-brand outline-none"
            >
              <option
                v-for="a in me.accounts"
                :key="a.number"
                :value="a.number"
              >
                {{ a.label }} · {{ a.number }} ({{ money(a.balance) }})
              </option>
            </select>
          </div>
          <div>
            <label class="block text-xs text-sub mb-1">Amount (USD)</label>
            <input
              v-model="payAmount"
              type="number"
              step="0.01"
              min="0"
              placeholder="50.00"
              class="w-full bg-ink border border-line rounded-lg px-3 py-2 text-text focus:border-brand outline-none"
            />
          </div>
          <button class="w-full bg-brand hover:bg-brand-dark text-white font-semibold py-2.5 rounded-lg transition">
            Make payment
          </button>
          <p v-if="payMsg" class="text-pos text-sm">{{ payMsg }}</p>
          <p v-if="payErr" class="text-neg text-sm">{{ payErr }}</p>
        </form>
      </div>

      <!-- Open a new account -->
      <form @submit.prevent="submitOpenAccount" class="bg-card border border-line rounded-2xl p-6 space-y-3">
        <h2 class="text-text font-semibold">Open a new account</h2>
        <p class="text-sub text-xs">
          Give your new account a nickname. It opens instantly with a $0.00 balance
          and a personalized welcome.
        </p>
        <div class="flex flex-wrap items-end gap-3">
          <div class="flex-1 min-w-[12rem]">
            <label class="block text-xs text-sub mb-1">Account nickname</label>
            <input
              v-model="newAccountLabel"
              placeholder="Vacation Fund"
              class="w-full bg-ink border border-line rounded-lg px-3 py-2 text-text focus:border-brand outline-none"
            />
          </div>
          <button class="bg-brand hover:bg-brand-dark text-white font-semibold px-5 py-2.5 rounded-lg transition">
            Open account
          </button>
        </div>
        <p v-if="openWelcome" class="text-text text-sm bg-brand/10 border border-brand/30 rounded-lg px-3 py-2">
          {{ openWelcome }}
        </p>
        <p v-if="openMsg" class="text-pos text-sm">{{ openMsg }}</p>
        <p v-if="openErr" class="text-neg text-sm">{{ openErr }}</p>
      </form>

      <!-- Statement -->
      <div class="bg-card border border-line rounded-2xl p-6">
        <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
          <h2 class="text-text font-semibold">Statement</h2>
          <div class="flex items-center gap-2">
            <input
              v-model="statementAccount"
              class="bg-ink border border-line rounded-lg px-3 py-1.5 text-text font-mono text-sm focus:border-brand outline-none w-36"
            />
            <button
              @click="loadStatement"
              class="text-sm border border-line hover:border-brand text-sub hover:text-text rounded-lg px-3 py-1.5 transition"
            >
              View
            </button>
          </div>
        </div>

        <p v-if="statementError" class="text-neg text-sm">{{ statementError }}</p>

        <div v-else-if="statement" class="overflow-x-auto">
          <p class="text-sub text-xs mb-3">
            Account {{ statement.account_number }} · {{ statement.holder }}
          </p>
          <table class="w-full text-sm">
            <thead>
              <tr class="text-sub/70 text-left border-b border-line">
                <th class="py-2 font-medium">Date</th>
                <th class="py-2 font-medium">Description</th>
                <th class="py-2 font-medium text-right">Amount</th>
                <th class="py-2 font-medium text-right">Balance</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="t in statement.transactions" :key="t.id" class="border-b border-line/50">
                <td class="py-2 text-sub whitespace-nowrap">{{ t.created_at.slice(0, 10) }}</td>
                <td class="py-2 text-text">{{ t.description }}</td>
                <td class="py-2 text-right font-mono" :class="t.amount < 0 ? 'text-neg' : 'text-pos'">
                  {{ t.amount < 0 ? "-" : "+" }}{{ money(Math.abs(t.amount)) }}
                </td>
                <td class="py-2 text-right font-mono text-sub">{{ money(t.balance_after) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </section>
</template>
