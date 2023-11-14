// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";

contract EchidnaBasicHelpers is EchidnaBase {
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

    function giveClampedAmount(
        uint8 fromAccId,
        uint8 toAccId,
        uint128 amount
    ) public {
        address from = getAccount(fromAccId);

        uint128 min = 1000;
        uint128 max = uint128(token.balanceOf(from));
        uint128 clampedAmount = min + (amount % (max - min + 1));
            (amount % (max - min + 1));

        give(fromAccId, toAccId, clampedAmount);
    }

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

    function receiveStreamsAllCycles(uint8 targetAccId) public {
        receiveStreams(targetAccId, type(uint32).max);
    }

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

    function collect(uint8 fromAccId, uint8 toAccId) public returns (uint128) {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        hevm.prank(from);
        uint128 collected = driver.collect(token, to);

        return collected;
    }

    function collectToSelf(uint8 targetAccId) public {
        collect(targetAccId, targetAccId);
    }

    function splitAndCollectToSelf(uint8 targetAccId) public {
        split(targetAccId);
        collectToSelf(targetAccId);
    }

    function receiveStreamsSplitAndCollectToSelf(uint8 targetAccId) public {
        receiveStreamsAllCycles(targetAccId);
        splitAndCollectToSelf(targetAccId);
    }
}
