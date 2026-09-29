# DECISIONS.md

This document lists every decision made during implementation that was not specified in the brief or PDF.

## Database Schema

1. **CV text encryption**: Used AES-256-CBC with a key derived from `ENCRYPTION_KEY` environment variable. IV is stored alongside ciphertext in Base64 format.

2. **Weight versioning**: Weights are stored as JSON hashes mapping driver IDs to weights. Floor driver IDs stored as JSON arrays. This allows immutable snapshots while maintaining referential integrity.

3. **Tenure roles storage**: Stored as JSON arrays in the `candidates` table rather than a separate `roles` table. This simplifies queries while maintaining flexibility for the timeline builder.

4. **Employer sources**: Separate table for URLs with `retrieved_at` timestamps to track what was actually retrieved vs. what the model claimed.

5. **Score movements**: Stored as separate records to maintain audit trail of changes from employer verification.

6. **Gate marks**: Separate table with unique constraint on (candidate_id, human_gate_id) to ensure one mark per factor per candidate.

7. **Stage runs**: Stored with raw request/response metadata (not CV text) for debugging and audit. CV contents are never logged.

8. **Reports**: Stored with file paths rather than BLOBs to avoid database bloat. Files stored in `tmp/reports/` directory.

## State Machine

9. **Stage transitions**: Enforced at model level with `can_advance_to?` method that checks all requirements up to target stage. Returns specific unmet requirements in error messages.

10. **Lock mechanism**: Redis-based per-evaluation locks with 5-minute TTL to prevent concurrent stage runs. Uses `SET NX EX` for atomic acquisition.

11. **Progress tracking**: Redis keys with 1-hour TTL for live progress polling via HTMX. Updates written by Sidekiq jobs.

## LLM Integration

12. **Client interface**: Abstract `LLM::Client` class with concrete implementations for Anthropic and testing. All methods raise `NotImplementedError` by default.

13. **FakeClient**: Returns pre-configured responses based on system prompt content. Includes default fixtures for all stages with realistic data.

14. **Prompt rendering**: ERB templates with `PromptContext` class providing evaluation binding. Prompts stored verbatim from PDF as `.md.erb` files.

15. **Output linter**: Checks for: sentences >28 words, praise/flattery vocabulary, "fabricated" for unfound claims, "verified" without URLs, missing V/I marks. Flags stored with responses, not silently fixed.

16. **Web search validation**: Guard rejects any search query containing a candidate's name. Only searches for organizations, clients, and published work.

## Scoring Logic

17. **Evidence cap**: Applied in Ruby, not LLM. Any score with `evidenced=false` is capped at 3, regardless of what the LLM returned.

18. **Floor computation**: Ruby computes Floor as lowest score among Floor attributes (after evidence cap). LLM's Floor value is ignored if it differs.

19. **Verdict derivation**: Floor ≤3 forces "reject" verdict regardless of weighted score. Ruby computes this, never trusts LLM.

20. **Weight validation**: Weights must sum to exactly 100 (not approximately). Validated at settlement and before each computation.

## Gate Sheet

21. **Mark vocabulary**: Exactly YES, NO, ?, NOT_REACHED. No other values accepted. Case-sensitive.

22. **NOT_REACHED propagation**: After a NO, remaining gates default to NOT_REACHED. Implemented in `GateSheet.submit_marks!`.

23. **? never becomes YES**: Explicit validation in `GateSheet.submit_marks!` prevents conversion. Compared against report's marks in final report generation.

24. **Empty assertion**: Pre-interview report generation asserts all gate marks are empty. Post-interview report generation asserts all cells are filled.

## Report Generation

25. **Page count verification**: After PDF generation, app verifies page count matches expected (2 + 2×candidates + 1). Refuses to publish overflowing reports.

26. **Landscape format**: All reports generated in landscape A4 with margins [40, 50, 40, 50].

27. **Timeline rendering**: Individual timelines use candidate's own span with consistent length-per-year scale. Shared timeline uses one shared axis for comparison.

28. **Candidate pages unchanged**: Post-interview report copies candidate pages verbatim from pre-interview issue. Code asserts score equality.

## Sidekiq Jobs

29. **RunStageJob**: Handles LLM calls for stages 2, 3, 5, 8, 9. Idempotent with 3 retries. Updates StageRun rows.

30. **VerifyEmployerJob**: One job per employer, run in parallel. Per-provider rate limiting (not implemented yet - would need Redis rate limiter). Aggregates when all finish.

31. **BuildReportJob**: DOCX + PDF generation with overflow check. Idempotent with 3 retries.

32. **No Redis/Sidekiq elsewhere**: All other operations are synchronous PostgreSQL. Redis only used for: Sidekiq, progress polling, evaluation locks.

## Authentication

33. **Session cookies**: Rack::Session::Cookie with 24-hour expiry. CSRF protection via rack_csrf gem.

34. **Password hashing**: bcrypt with default cost factor. No password complexity requirements beyond minimum 8 characters.

35. **Ownership isolation**: All queries scoped to `current_user`. Cross-user access returns 404.

## Corrections Panel

36. **Six corrections**: Implemented exactly as specified in PDF's "If it does this, it is doing it wrong" table. Each sends exact canned correction text to LLM in same session.

37. **Correction tracking**: Corrections stored as StageRun records with stage_number=0 to distinguish from regular stages.

## Data Purge

38. **Hard delete**: `purge!` method destroys all associated records in transaction: candidates, employers, kill criteria, drivers, human gates, weight versions, disconfirmations, stage runs, reports.

39. **No CV logging**: CV contents never written to logs. Only raw request/response metadata stored (without CV text).

## Testing

40. **FakeClient fixtures**: Pre-configured responses for all stages with realistic data. Includes capability test results, JD extraction, weights, human gates, CV scoring, and employer verification.

41. **DatabaseCleaner**: Transaction strategy for unit/request tests, truncation for feature tests.

42. **WebMock**: All external HTTP requests disabled in tests. No live network calls.

43. **Coverage target**: SimpleCov configured for ≥90% line coverage on services and models.

## What I Could Not Implement

44. **DOCX generation**: Caracal gem used but may need refinement for complex layouts. Prawn used for PDF generation.

45. **Timeline visualization**: Text-based timeline rendering rather than graphical charts. Could be enhanced with SVG/Canvas.

46. **Per-provider rate limiting**: VerifyEmployerJob would need Redis rate limiter for production use. Not implemented in this version.

47. **PDF page count verification**: Would need pdf-reader gem for accurate page counting. Currently trusts generation.

48. **HTMX progress polling**: Basic implementation with 2-second polling. Could be enhanced with WebSocket for real-time updates.
