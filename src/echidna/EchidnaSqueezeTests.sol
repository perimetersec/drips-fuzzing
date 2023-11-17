// SPDX-License-Identifier: MIT

import "./EchidnaBasicHelpers.sol";
import "./EchidnaSplitsHelpers.sol";
import "./EchidnaStreamsHelpers.sol";
import "./EchidnaSqueezeHelpers.sol";

contract EchidnaSqueezeTests is
    EchidnaBasicHelpers,
    EchidnaSplitsHelpers,
    EchidnaStreamsHelpers,
    EchidnaSqueezeHelpers
{
    ///@notice Test internal accounting after squeezing
    function testSqueeze(uint8 receiverAccId, uint8 senderAccId) public {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);

        uint256 receiverDripsAccId = getDripsAccountId(receiver);

        uint128 squeezableBefore = getSqueezableAmount(sender, receiver);
        uint128 splittableBefore = drips.splittable(receiverDripsAccId, token);

        uint128 squeezedAmt = squeezeWithDefaultHistory(
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
        uint128 squeezed = squeezeWithDefaultHistory(
            receiverAccId,
            senderAccId
        );

        assert(squeezable == squeezed);
    }

    function testSqueezableVsReceived(uint8 targetAccId) public heavy {
        address target = getAccount(targetAccId);

        // store the current squeezable and receivable amount
        uint128 squeezable = getTotalSqueezableAmountForUser(target);
        uint128 receivableBefore = getReceivableAmountForUser(target);

        // remove all streaming balance from the system, so that warping to
        // the future will not increase the receivable/squeezable amount
        setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);

        // warp to the point in time where the streams are receivable
        hevm.warp(getCurrentCycleEnd() + 1);

        uint128 receivableAfter = getReceivableAmountForUser(target);

        // sanity check
        assert(receivableAfter >= receivableBefore);

        uint128 receiveableDelta = receivableAfter - receivableBefore;

        // squeezable before should match receivable now
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

        uint128 amount0 = squeezeWithFuzzedHistory(
            receiverAccId,
            senderAccId,
            hashIndex,
            receiversRandomSeed
        );

        uint128 amount1 = squeezeWithFuzzedHistory(
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

        setStreamBalanceWithdrawAll(senderAccId);

        uint128 squeezableAfter = getSqueezableAmount(sender, receiver);

        assert(squeezableAfter == squeezableBefore);
    }

    function testWithdrawAllTokens() external heavy {
        // remove all splits to prevent tokens from getting stuck in case
        // there are splits to self
        removeAllSplits(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        removeAllSplits(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        removeAllSplits(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        removeAllSplits(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);

        squeezeAllSenders(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        squeezeAllSenders(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        squeezeAllSenders(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        squeezeAllSenders(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);

        receiveStreamsSplitAndCollectToSelf(
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]
        );
        receiveStreamsSplitAndCollectToSelf(
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]
        );
        receiveStreamsSplitAndCollectToSelf(
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]
        );
        receiveStreamsSplitAndCollectToSelf(
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]
        );

        setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);

        uint256 dripsBalance = token.balanceOf(address(drips));
        uint256 user0Balance = token.balanceOf(ADDRESS_USER0);
        uint256 user1Balance = token.balanceOf(ADDRESS_USER1);
        uint256 user2Balance = token.balanceOf(ADDRESS_USER2);
        uint256 user3Balance = token.balanceOf(ADDRESS_USER3);

        uint256 totalUserBalance = user0Balance +
            user1Balance +
            user2Balance +
            user3Balance;

        assert(dripsBalance == 0);
        assert(totalUserBalance == STARTING_BALANCE * 4);
    }

    ///@notice Squeezing should never revert
    function testSqueezeWithDefaultHistoryShouldNotRevert(
        uint8 receiverAccId,
        uint8 senderAccId
    ) public {
        try
            EchidnaSqueezeHelpers(address(this)).squeezeWithDefaultHistory(
                receiverAccId,
                senderAccId
            )
        {} catch {
            assert(false);
        }
    }

    function testSqueezeWithFuzzedHistoryShouldNotRevert(
        uint8 receiverAccId,
        uint8 senderAccId,
        uint256 hashIndex,
        bytes32 receiversRandomSeed
    ) public {
        address sender = getAccount(senderAccId);
        require(
            getStreamsHistory(sender).length >= 2,
            "need at least 2 history entries"
        );

        try
            EchidnaSqueezeHelpers(address(this)).squeezeWithFuzzedHistory(
                receiverAccId,
                senderAccId,
                hashIndex,
                receiversRandomSeed
            )
        {} catch {
            assert(false);
        }
    }

    function testWithdrawAllTokensShouldNotRevert() public heavy {
        try
            EchidnaSqueezeTests(address(this)).testWithdrawAllTokens()
        {} catch {
            assert(false);
        }
    }
}
