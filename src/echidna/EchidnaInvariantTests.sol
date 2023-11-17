// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";

/**
 * @title Mixin containing invariant tests
 * @author Rappie
 */
contract EchidnaInvariantTests is EchidnaBase {
    /**
     * @notice Withdrawing any amount directly from Drips should fail
     * @param amount Amount to withdraw
     */
    function invariantWithdrawShouldAlwaysFail(uint256 amount) public {
        require(amount > 0, "withdraw amount must be > 0");

        try drips.withdraw(token, address(this), amount) {
            assert(false);
        } catch {}
    }

    /**
     * @notice `amtPerSec` should never be lower than `drips.minAmtPerSec()`
     * @param targetAccId Account id of the receiver
     * @param index Index of the receiver
     */
    function invariantAmtPerSecVsMinAmtPerSec(uint8 targetAccId, uint256 index)
        public
    {
        address target = getAccount(targetAccId);

        StreamReceiver[] memory receivers = getStreamReceivers(target);
        require(receivers.length > 0, "no receivers");

        index = index % receivers.length;
        uint160 amtPerSec = receivers[index].config.amtPerSec();

        assert(amtPerSec >= drips.minAmtPerSec());
    }

    /**
     * @notice The total of all internal balances should match token balance
     * of the Drips contract
     */
    function invariantAccountingVsTokenBalance() public {
        uint256 tokenBalance = token.balanceOf(address(drips));
        uint256 dripsBalancesTotal = getDripsBalancesTotalForAllUsers();

        assert(tokenBalance == dripsBalancesTotal);
    }

    /**
     * @notice The sum of all `amtDelta`s for an account should be zero
     * @param targetAccId Target account to perform the test on
     */
    function invariantSumAmtDeltaIsZero(uint8 targetAccId) public heavy {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint32 maxEnd = getMaxEndForAllUsers();

        uint32 firstCycle = getCycleFromTimestamp(STARTING_TIMESTAMP);
        uint32 lastCycle = getCycleFromTimestamp(maxEnd);

        require(maxEnd > 0, "no cycles");
        require(firstCycle != lastCycle, "only one cycle");

        // limit amount of cycles for gas & memory savings
        require(lastCycle - firstCycle < 1000, "too many cycles");

        int256 sumAmtDelta = 0;

        for (uint32 cycle = firstCycle; cycle <= lastCycle; cycle++) {
            (int128 thisCycle, int128 nextCycle) = drips.getAmtDeltaForCycle(
                targetDripsAccId,
                token,
                cycle
            );

            sumAmtDelta += int256(thisCycle);
            sumAmtDelta += int256(nextCycle);
        }

        assert(sumAmtDelta == 0);
    }
}
