# Automated responses rollout runbook

## Scope

This runbook is the production-only completion path for the automated-response catalog, historical backfill and Lemon Squeezy repricing. Schema, backend, dashboard and landing code are deployable; the steps below intentionally stop before any production commercial mutation until the owner reviews real data.

## Mandatory stop 1 — historical impact

1. Run from `backend/` with production database credentials: `npm run migrate:responses:dry-run -- --output=<new-report.json>`.
2. Review all ten report sections, especially `businessesThatWouldPause`, `averageAutomatedMessagesPerTurn`, class B and ledger invariant issues.
3. Credit every business in `businessesThatWouldPause`; record those ids in `creditedBusinessIds`.
4. If the average exceeds `1.6`, review the published limits with the owner and record `ownerApprovedAboveMessageRatio: true` only after that decision.
5. Set `ownerApproved: true` without editing `payload` or `payloadSha256`. Any payload edit invalidates the report.

Do not continue while the ledger has drift, while a pausing business lacks credit evidence, or without the owner's explicit approval.

## Backfill and reconciliation

Set `AUTOMATED_RESPONSE_MIGRATION_APPROVAL_FILE=<approved-report.json>` and the exact confirmation `AUTOMATED_RESPONSE_MIGRATION_APPROVED=YES`, then run `npm run db:migrate`. Migration `2026-08-06-10` materializes the reviewed A/B lists inside its transaction, rebuilds A from outbound messages, grants B a full cycle, leaves C/D untouched, resets the changed alert stage and aborts on counter drift.

Before production, `npm run migrate:responses:test-idempotence` may be used against staging: it executes the backfill twice and always rolls back. After the production backfill, query `v_response_accounting_health`; the result must be empty before enforcement is deployed.

## Mandatory stop 2 — new Lemon Squeezy variants

1. In Lemon Squeezy create new recurring variants for WhatsApp `$29`, Pro `$69` and Business `$129`. Do not archive the old variants.
2. Verify their ids, set all three `LS_NEW_VARIANT_*` values, and set `SUBSCRIPTION_REPRICING_MAPPING_APPROVED=YES`.
3. Run `npm run db:migrate`; migration `2026-08-06-11` maps the plan catalog to the three new, distinct numeric ids. This uses sequence 11 because migration 07 is immutable and never guessed production ids.
4. Run `npm run migrate:subscriptions:prices -- --dry-run --output=<new-repricing-report.json>`.
5. Review every subscription, set `ownerApproved: true` without changing candidates or their digest, and set `SUBSCRIPTION_REPRICING_APPROVED=YES`.
6. Run `npm run migrate:subscriptions:prices -- --apply --approval-file=<approved-report.json>`.

The script skips subscriptions already on target, sends only `variant_id` and `disable_prorations: true`, never sends `invoice_immediately`, rereads every subscription, writes a result report and dispatches the localized owner price-update notification after successful verification. Archive old variants only after the result contains zero failures and a provider-side query shows zero subscriptions on them.

## Coordinated deploy

Deploy the single enforcement build only after both stops and reconciliation succeed. Keep the previous application build available for technical rollback; the additive schema remains compatible with it. For 24 hours monitor response-accounting drift, partial-turn truncation, response blocks by kind, prepaid depletion, trial exhaustion, provider errors and response-cost alerts. No feature flag or permanent enforcement bypass exists.

## Local rehearsal evidence — 2026-08-06

- Read-only response dry run: report created successfully in the Docker backend environment.
- Backfill idempotence: two executions inside a rolled-back transaction; identical events and counters.
- Repricing dry run: completed with zero local live subscriptions and no PATCH requests.
- Script unit tests: four passed.
- Backend TypeScript and Nest production build: passed.
- No production database migration, credit, Lemon Squeezy PATCH or variant archival was performed.
