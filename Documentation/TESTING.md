# Testing

## Automated (`tools/test.sh`)

The engine's tests, with Swift Testing. They must run without a network
connection (§13.4).

| Test | Checks |
|---|---|
| `formatIsSelfConsistent` | the MacMusic contract's byte rate and block align follow from its other values |

Stage 0: 1 test, passing (2026-10-08).

## Checking a file in MacMusic (from Stage 1)

A converted WAV is only known to work once MacMusic has imported and
played it (§13.5). The route: copy it onto MacMusic's `Transfer.dsk`
with hfsutils, import it in Mini vMac, play it; then on the real Plus.
Steps to be written in Stage 1.
