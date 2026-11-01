# Gap Audit — Tier 8 / Agent Yeller Arbitrage Daemon
Date: 2026-10-22 (side chat, 11:22 CDT)
Source: Richard-supplied paste in chat. NOT in the verified Rich Gang AI codebase
(`~/workspace/rich_gang_ai` Flutter/Dart + Rust libdaemon.so). NOT built, NOT run,
NOT deployed, NO capital deployed, NO trades executed.

## Verdict
As pasted, this is a fragmented spec + partial snippets, not a runnable daemon.
It does not compile as a single crate, and several snippets violate the
invariants (INV-1 to INV-6) they claim to enforce. Do not present it as
production, live, TRAIGA-verified, or consensus-verified.

## Will-not-compile / structural breaks (verified by reading the paste)
- Two different package names / Cargo.tomls: `rich-gang-arbitrage-daemon`
  (no thiserror/hmac/hex/uuid/tracing) vs `tier8-arbitrage-daemon` (with them).
- Duplicate definitions: FlashLoanCalculator x3, MetricsRegistry x2,
  InventoryManager x2, DepthWalker x2, KillSwitch x3, AuditStore x3,
  DaemonError x2 (enum with Serialize vs thiserror enum — incompatible),
  multiple `main()`s, multiple Theta/Gamma/Alpha versions with different APIs.
- Missing / never supplied: Beta, Zeta, Delta, Epsilon's WsClient/LogEntry,
  Config, Store, QuoteFrame, MtlsSigner, PrivateRelayPool, RealThreatClient,
  MinHashAnalyzer, NonceManager (vs the supplied NoncePool), `resources`.
- Type mismatches across versions: `Opportunity.estimated_gas_units`
  used/set in some Alpha/Gamma versions, absent from the struct in others;
  `QuoteProvenance::from` vs `::from_quote`; `MarketState.recent_pnl_shock`
  is `f64` in types.rs, treated as `Option` in one Theta version;
  Gamma pseudo-code fragment with `ok_or_else(|| AgentReport::veto(...))?`
  on an AgentReport (not a Result) left in the paste.

## Invariant violations in the supplied code itself
- INV-1 (no defaults/guessing): one Gamma version does
  `opp.estimated_gas_units.unwrap_or(250_000.0)` — a hardcoded fallback.
  Alpha sets `slippage_cost_usd: 0.0` without a depth walk in the main path.
  First main() hardcodes $50,000 Binance USDC and marks trades successful
  on an inventory check alone.
- INV-2 (unanimous Alpha/Beta/Gamma/Zeta/Theta): first main() runs zero
  verifiers. Replay harness checks only Beta + Gamma, ignores Zeta/Theta,
  uses a hardcoded latency of 25ms and shock 0.0 — simulated inputs.
- INV-3 (fail-closed): Theta versions persist latch/state with
  `.ok()` / `let _ =` — store failures silently ignored. FeedWatchdog
  only logs + notifies on a stale feed; it does not kill/halt by itself.
- INV-4 (hash-chained audit): one AuditStore::append stub returns `Ok(())`
  and writes nothing. Real versions' `compute_file_tail_hash` is a stub
  returning the genesis zero hash on every restart, so the chain does not
  resume — prior history can be replaced undetected after a restart.
- INV-5 (external signer): Delta / MtlsSigner are referenced in main.rs
  only. No signer code, mTLS config, or key-isolation proof was supplied.
- INV-6 (atomic preflight): `preflight_check` is an empty stub returning
  `Ok(())` — no flash-loan, inventory-skew, or EIP-1559 validation.
  `Epsilon::parse_swap_logs` always returns
  `Err("parse_swap_logs implementation required")`, so settlement can
  never succeed on that path.
- Zeta (security/sanctions/MinHash) is described in prose only — no code.

## TRAIGA note
The paste hardcodes `"TRAIGA_ATTESTATION": "VERIFIED_COMPLIANT"` into a
trade audit record. That is self-attestation in code, not a verification.
No compliance determination is made here, and none should be claimed in
any listing, pitch, or post from this material.

## Honest next sequence (if Richard wants this built for real)
1. Freeze ONE crate: one Cargo.toml, one types.rs, one version per module.
2. Supply or build the missing agents (Beta, Zeta, Delta signer) — real APIs
   verified first, per the no-mock rule.
3. Fix INV breaks above, starting with audit tail-hash resume and removing
   the 250k gas default.
4. `cargo test` on host with real unit tests for DepthWalker, FlashLoan,
   Gamma, Theta, Audit chain-resume — report counts only after they run.
5. Replay harness on a real recorded corpus only; gate capital on its
   total_net exactly as the harness prints — do not pre-claim an edge.

## Verification run — 2026-10-22 ~11:24-11:35 CDT (Richard: "Verify the code passes and checks out")
Method: assembled the most complete version of each pasted module into an
isolated crate in /tmp/arb_verify (tier8 Cargo.toml, Rust 1.99.1), ran cargo.

- FULL assembled lib: `cargo check` FAILED — 13 errors, all E0038.
  `KillStore` and `BreakerStore` use `async fn` in a trait and are then used
  as `Arc<dyn KillStore>` / `Arc<dyn BreakerStore>`; async trait methods are
  not dyn-compatible. Log: /tmp/arb_verify_check.log
  ("could not compile `tier8-arbitrage-daemon` (lib) due to 13 previous errors")
- Core subset (same crate minus KillSwitch + Theta): `cargo check` PASSES
  with 1 warning (NonceGuard fields never read). Modules that compile on
  their own: types, audit, depth, flash_loan, inventory, nonce_pool,
  watchdog, metrics, alpha, gamma.
- Tests: `cargo test` on the passing subset runs **0 tests** — the paste
  contains no tests at all, so no logic (spread, flash fee, skew, CUSUM,
  audit chain) is proven by a test result.
- Full daemon (main.rs / replay / Epsilon): could not even be assembled —
  Beta, Zeta, Delta, Config, Store, QuoteFrame, WsClient, signer and relay
  types were never supplied. That failure is structural, not a typo.

Conclusion: the code does NOT pass and does NOT check out as a daemon.
Two modules compile in isolation; the safety-critical modules (KillSwitch,
Theta breaker) are exactly the ones that fail, and nothing is test-proven.
