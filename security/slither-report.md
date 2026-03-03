# Slither Report — TokenRewards.sol

**Date**: 2026-03-03
**Slither version**: 0.11.5
**Solidity**: ^0.8.24 (solc 0.8.24)
**Config**: `slither.config.json` (excluded: naming-convention, pragma, dependencies, lib/test/script)

## Summary

| Severity | Count |
|----------|-------|
| High     | 0     |
| Medium   | 0     |
| Low      | 0     |
| Informational | 6 (all same detector) |

**Result**: PASS — no medium+ findings.

---

## Findings

### 1. costly-loop (Informational) — 6 instances

**Detector**: `costly-operations-inside-a-loop`

**Description**: `_removeHolder()` performs storage operations (`_holders.pop()`, `delete _isHolder[account]`, `delete _holderIndex[account]`) that can be reached from loops in `batchMintTokenA` and `distributeTokenB`.

**Affected code**: `src/TokenRewards.sol:235-250` (`_removeHolder`)

**Call paths**:
1. `batchMintTokenA` → `_mint` → `_update` → `_removeHolder`
2. `distributeTokenB` → `_mint` → `_update` → `_removeHolder`

**Classification**: **False positive** — safe by design.

**Rationale**:
- In `batchMintTokenA`, `_removeHolder` is called inside `_update` which fires on each `_mint`. However, a mint **increases** balance, so `balanceOf(from, TOKEN_A) == 0` is only checked for the `from` address, which is `address(0)` during minting. The `from != address(0)` guard prevents `_removeHolder` from executing at all during mints. No storage writes happen through this path.
- In `distributeTokenB`, the loop mints **Token B** (id=1). The `_removeHolder` path only triggers for `ids[i] == TOKEN_A` (id=0). Since distribute only mints Token B, the holder removal branch is never reached.
- Even in the theoretical worst case (a transfer loop), `_removeHolder` is O(1) per call thanks to swap-and-pop — no iteration over the holders array.

**Action**: No fix needed. Documented as acknowledged informational.

---

## Excluded Detectors

| Detector | Reason |
|----------|--------|
| `naming-convention` | False positives on UPPER_CASE constants (`TOKEN_A`, `TOKEN_B`, `MINTER_ROLE`, etc.) which follow Solidity convention |
| `pragma` | We use `^0.8.24` intentionally for Foundry compatibility |

## Excluded Paths

- `lib/` — OpenZeppelin dependencies (audited separately)
- `test/` — test contracts
- `script/` — deployment scripts
