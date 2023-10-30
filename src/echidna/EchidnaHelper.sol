// SPDX-License-Identifier: MIT

import "./EchidnaAccounting.sol";
import "./Debugger.sol";

contract EchidnaHelper is EchidnaAccounting {
    function give(
        uint8 fromAccId,
        uint8 toAccId,
        uint128 amount
    ) public {
        require(TOGGLE_GIVE_ENABLED);

        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        uint256 toDripsAccId = driver.calcAccountId(to);

        hevm.prank(from);
        driver.give(toDripsAccId, token, amount);
    }

    function giveClampedAmount(
        uint8 fromAccId,
        uint8 toAccId,
        uint128 amount
    ) public {
        address from = getAccount(fromAccId);

        uint128 MIN_AMOUNT = 1000;
        uint128 MAX_AMOUNT = uint128(token.balanceOf(from));
        uint128 clampedAmount = MIN_AMOUNT +
            (amount % (MAX_AMOUNT - MIN_AMOUNT + 1));

        give(fromAccId, toAccId, clampedAmount);
    }

    function _squeeze(uint8 receiverAccId, uint8 senderAccId)
        internal
        returns (uint128)
    {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);
        uint256 receiverDripsAccId = driver.calcAccountId(receiver);
        uint256 senderDripsAccId = driver.calcAccountId(sender);

        uint128 amount = drips.squeezeStreams(
            receiverDripsAccId,
            token,
            senderDripsAccId,
            bytes32(0),
            getStreamsHistory(sender)
        );

        return amount;
    }

    function squeeze(uint8 receiverAccId, uint8 senderAccId)
        external
        returns (uint128)
    {
        return _squeeze(receiverAccId, senderAccId);
    }

    function squeezeToSelf(uint8 targetAccId) public {
        _squeeze(targetAccId, targetAccId);
    }

    function squeezeAllSenders(uint8 targetAccId) public {
        _squeeze(targetAccId, ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        _squeeze(targetAccId, ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        _squeeze(targetAccId, ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        _squeeze(targetAccId, ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);
    }

    function receiveStreams(uint8 targetAccId, uint32 maxCycles)
        public
        returns (uint128)
    {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = driver.calcAccountId(target);

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
        uint256 targetDripsAccId = driver.calcAccountId(target);

        (uint128 collectableAmt, uint128 splitAmt) = drips.split(
            targetDripsAccId,
            token,
            new SplitsReceiver[](0)
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