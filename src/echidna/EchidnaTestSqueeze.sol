// SPDX-License-Identifier: MIT

import "./EchidnaTest.sol";

contract EchidnaTestSqueeze is EchidnaTest {
    ///@notice Test internal accounting after squeezing
    function testSqueeze(uint8 receiverAccId, uint8 senderAccId) public {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);

        uint256 receiverDripsAccId = getDripsAccountId(receiver);

        uint128 squeezableBefore = getSqueezableAmount(sender, receiver);
        uint128 splittableBefore = drips.splittable(receiverDripsAccId, token);

        uint128 squeezedAmt = _squeezeWithDefaultHistory(
            receiverAccId,
            senderAccId
        );

        uint128 squeezableAfter = getSqueezableAmount(sender, receiver);
        uint128 splittableAfter = drips.splittable(receiverDripsAccId, token);

        assert(squeezableAfter == squeezableBefore - squeezedAmt);
        assert(splittableAfter == splittableBefore + squeezedAmt);

        if (squeezedAmt > 0) {
            assert(squeezableAfter < squeezableBefore);
            assert(splittableAfter > splittableBefore);
        } else {
            assert(squeezableAfter == squeezableBefore);
            assert(splittableAfter == splittableBefore);
        }
    }

    ///@notice `drips.squeezeStreamsResult` should match actual squeezed amount
    function testSqueezeViewVsActual(uint8 receiverAccId, uint8 senderAccId)
        public
    {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);

        uint128 squeezable = getSqueezableAmount(sender, receiver);
        uint128 squeezed = _squeezeWithDefaultHistory(
            receiverAccId,
            senderAccId
        );

        assert(squeezable == squeezed);
    }

    function testSqueezableVsReceived(uint8 targetAccId) public heavy {
        address target = getAccount(targetAccId);

        uint128 squeezable = getTotalSqueezableAmountForUser(target);
        uint128 receivableBefore = getReceivableAmountForUser(target);

        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);

        uint256 currentTimestamp = block.timestamp;
        uint256 futureTimestamp = getCurrentCycleEnd() + 1;

        hevm.warp(futureTimestamp);

        uint128 receivableAfter = getReceivableAmountForUser(target);

        receiveStreamsAllCycles(targetAccId);

        assert(receivableAfter >= receivableBefore);
        uint128 receiveableDelta = receivableAfter - receivableBefore;

        assert(squeezable == receiveableDelta);
    }

    function testSqueezeWithFullyHashedHistory(
        uint8 receiverAccId,
        uint8 senderAccId
    ) public {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);

        uint128 squeezableBefore = getSqueezableAmount(sender, receiver);

        StreamsHistory[] memory history = getStreamsHistory(sender);
        for (uint256 i = 0; i < history.length; i++) {
            history[i].streamsHash = drips.hashStreams(history[i].receivers);
            history[i].receivers = new StreamReceiver[](0);
        }

        uint128 squeezedAmt = _squeeze(
            receiverAccId,
            senderAccId,
            bytes32(0),
            history
        );

        uint128 squeezableAfter = getSqueezableAmount(sender, receiver);

        assert(squeezedAmt == 0);
        assert(squeezableAfter == squeezableBefore);
    }

    function testSqueezeTwice(
        uint8 receiverAccId,
        uint8 senderAccId,
        uint256 hashIndex,
        bytes32 receiversRandomSeed
    ) external {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);

        uint128 amount0 = _squeezeWithFuzzedHistory(
            receiverAccId,
            senderAccId,
            hashIndex,
            receiversRandomSeed
        );

        uint128 amount1 = _squeezeWithFuzzedHistory(
            receiverAccId,
            senderAccId,
            hashIndex,
            receiversRandomSeed
        );

        assert(amount1 == 0);
    }

    function testSqueezableAmountCantBeUndone(
        uint8 receiverAccId,
        uint8 senderAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) external {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);

        uint128 squeezableBefore = getSqueezableAmount(sender, receiver);

        setStreams(
            receiverAccId,
            senderAccId,
            amountPerSec,
            startTime,
            duration,
            balanceDelta
        );

        uint128 squeezableAfter = getSqueezableAmount(sender, receiver);

        assert(squeezableAfter == squeezableBefore);
    }

    function testSqueezableAmountCantBeWithdrawn(
        uint8 receiverAccId,
        uint8 senderAccId
    ) external {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);

        uint128 squeezableBefore = getSqueezableAmount(sender, receiver);

        _setStreamBalanceWithdrawAll(senderAccId);

        uint128 squeezableAfter = getSqueezableAmount(sender, receiver);

        assert(squeezableAfter == squeezableBefore);
    }
}
