// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";

/**
 * @title Mixin containing basic helper functions
 * @author Rappie <rappie@perimetersec.io>
 */
contract EchidnaBasicHelpers is EchidnaBase {
    /**
     * @notice Give balance to an account
     * @param fromAccId Account id of the giver
     * @param toAccId Account id of the receiver
     * @param amount Amount to give
     */
    function give(
        uint8 fromAccId,
        uint8 toAccId,
        uint128 amount
    ) public {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        uint256 toDripsAccId = getDripsAccountId(to);

        hevm.prank(from);
        driver.give(toDripsAccId, token, amount);
    }

    /**
     * @notice Give a clamped amount to an account
     * @param fromAccId Account id of the giver
     * @param toAccId Account id of the receiver
     * @param amount Amount to give
     */
    function giveClampedAmount(
        uint8 fromAccId,
        uint8 toAccId,
        uint128 amount
    ) public {
        address from = getAccount(fromAccId);

        uint128 min = 1000;
        uint128 max = uint128(token.balanceOf(from));
        uint128 clampedAmount = min + (amount % (max - min + 1));

        give(fromAccId, toAccId, clampedAmount);
    }

    /**
     * @notice Receive streams
     * @param targetAccId Account id of the receiver
     * @param maxCycles Maximum number of cycles to receive
     * @return Amount received
     * @dev Receiving means moving receivable (already streamed) balance to
     * splittable (available for splitting) balance
     */
    function receiveStreams(uint8 targetAccId, uint32 maxCycles)
        public
        returns (uint128)
    {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint128 receivedAmt = drips.receiveStreams(
            targetDripsAccId,
            token,
            maxCycles
        );

        return receivedAmt;
    }

    /**
     * @notice Receive streams for all possible cycles
     * @param targetAccId Account id of the receiver
     * @return Amount received
     * @dev We pass maxuint32 to receive all possible cycles
     */
    function receiveStreamsAllCycles(uint8 targetAccId)
        public
        returns (uint128)
    {
        return receiveStreams(targetAccId, type(uint32).max);
    }

    /**
     * @notice Split received funds
     * @param targetAccId Account to have their funds split
     * @return Amount collectable and amount split
     * @dev Splitting means moving splittable (available for splitting) balance
     * to collectable (available for collecting) balance
     */
    function split(uint8 targetAccId) public returns (uint128, uint128) {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        (uint128 collectableAmt, uint128 splitAmt) = drips.split(
            targetDripsAccId,
            token,
            getSplitsReceivers(target)
        );

        return (collectableAmt, splitAmt);
    }

    /**
     * @notice Collect funds
     * @param fromAccId Account id of the giver
     * @param toAccId Account id of the receiver
     * @return Amount collected
     * @dev Collecting means moving withdrawing collectable funds to actual
     * balance of the erc20 token
     */
    function collect(uint8 fromAccId, uint8 toAccId) public returns (uint128) {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        hevm.prank(from);
        uint128 collected = driver.collect(token, to);

        return collected;
    }

    /**
     * @notice Collect funds to self
     * @param targetAccId Target account
     */
    function collectToSelf(uint8 targetAccId) public {
        collect(targetAccId, targetAccId);
    }

    /**
     * @notice Split and collect funds to self
     * @param targetAccId Target account
     * @dev Extra helper that narrows the search space for the fuzzer
     */
    function splitAndCollectToSelf(uint8 targetAccId) public {
        split(targetAccId);
        collectToSelf(targetAccId);
    }

    /**
     * @notice Receive streams, split and collect funds to self
     * @param targetAccId Target account
     * @dev Extra helper that narrows the search space for the fuzzer
     */
    function receiveStreamsSplitAndCollectToSelf(uint8 targetAccId) public {
        receiveStreamsAllCycles(targetAccId);
        splitAndCollectToSelf(targetAccId);
    }
}
