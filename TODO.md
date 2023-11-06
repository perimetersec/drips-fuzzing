## Todo
- Tests/Invariants
  - Test squeezing with fuzzed history lists
  - Splitting
- Helpers
  - Improve corpus quality by incentivizing Echidna to make large lists of stream receivers

## Done
- Get insight into coverage
  - Remove proxy so Echidna can generate coverage reports
  - Analyze coverage reports
- Fuzzing campaign runnable without changes to the Drips code
- Performance
  - Optimize fuzzing code (Cancelled for now, due to possible Echidna issues)
- PvE fuzzing PoC
- Medusa compatibility & testing
- Big round of refactors & cleanup
- Performance
  - Make heavy/destructive functions togglable

## Planning (conceptual)
- Max coverage
  - 100% coverage on coverage report
  - Finish all known invariants
- Set up cloud fuzzing (fuzzy.fyi)
- PvE fuzzing
- Documenting
  - NatSpec
- Merge to Drips repo
  - Pull request + docs/guide

## Backlog
- Incorporate fuzzing in Drips repo
	- Pull request + docs/guide
- Helpers
	- Adding large amounts of StreamReceivers (100s or 1000s)
- Tests
	- Continue working on `testExperimentalBalanceAt`
	- Check if `balanceAt` reverts for timestamps before the last update
	- Adding/removing streams should not change balance
	- Add `testSetStreamsShouldRevert` (duplicates, unsorted, 0 amount per second)
	- Test internal accounting changes after `give`
	- Check is `balanceAt` increases in the future if there is an active stream
	- Test for reentrancy attacks in `Drips.withdraw`
	- Multiple small `receiveStreams` calls should yield the same result as one big one (with `maxCycles`)
	- `realBalanceDelta` returned by `setStreams` should never be smaller/larger than supplied `balanceDelta`
	 - create a stream and warp to the end. Funds in should == to founds out.
- PvE fuzzing campaign
	- Adversarial fuzzing instead of specification-oriented
	- Based on the same helpers
	- Introduce new user: attacker
	- New test: attacker should not be able to increase their balance by X percent
	- Implementation
		- Special `prank` helper that changes behaviour when attack is starting
		- `getAccount` should change behaviour when attack is starting
- Features
	- Sending tokens directly to Drips
	- More & dynamic accounts
	- Different seconds per cycle
- Misc
	- Improve fuzzing speed
	- Further investigate mutation testing edge cases
	- Stateless fuzzing of `calcBalance`
	- Investigate possible DoS attacks on `receiveStreams`,  `split`, etc.
