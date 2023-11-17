// SPDX-License-Identifier: MIT

import "./EchidnaBasicHelpers.sol";
import "./EchidnaSplitsHelpers.sol";
import "./EchidnaStreamsHelpers.sol";
import "./EchidnaSqueezeHelpers.sol";

/**
 * @title Mixin containing tests for squeezing
 * @author Rappie
 */
contract EchidnaSqueezeTests is
    EchidnaBasicHelpers,
    EchidnaSplitsHelpers,
    EchidnaStreamsHelpers,
    EchidnaSqueezeHelpers
{
    /**
     * @notice Test internal accounting after squeezing
     * @param receiverAccId Account id of the receiver
     * @param senderAccId Account id of the sender
     */
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

    /**
     * @notice `drips.squeezeStreamsResult` should match actual squeezed amount
     * @param receiverAccId Account id of the receiver
     * @param senderAccId Account id of the sender
     */
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

    /**
     * @notice Squeezable amount should be equal to receivable amount in the future
     * @param targetAccId Account id of the receiver
     */
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

    /**
     * @notice Squeezing with a fully hashed history should do nothing
     * @param receiverAccId Account id of the receiver
     * @param senderAccId Account id of the sender
     */
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

    /**
     * @notice Squeezing the same part(s) of history should only work the first time
     * @param receiverAccId Account id of the receiver
     * @param senderAccId Account id of the sender
     * @param hashIndex Index of the history entry to squeeze
     * @param receiversRandomSeed Random seed used to determine which history entries
     * to leave out of the squeeze (by hashing them)
     */
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

    /**
     * @notice Already streamed (and therefore squeezable) balance should not be
     * affected changing the stream receivers
     * @param receiverAccId Account id of the receiver
     * @param senderAccId Account id of the sender
     * @param amountPerSec Amount per second to stream
     * @param startTime Start time for the stream
     * @param duration Duration for the stream
     * @param balanceDelta Amount to update stream balance with
     */
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

    /**
     * @notice Already streamed (and therefore squeezable) balance should not be
     * affected by withdrawing all streaming balance
     * @param receiverAccId Account id of the receiver
     * @param senderAccId Account id of the sender
     */
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

    /**
     * @notice Check internal and external balances after withdrawing all funds
     * from the system
     */
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

    /**
     * @notice Squeezing with default history (all history entries) should
     * not revert
     * @param receiverAccId Account id of the receiver
     * @param senderAccId Account id of the sender
     */
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

    /**
     * @notice Squeezing with fuzzed history should not revert
     * @param receiverAccId Account id of the receiver
     * @param senderAccId Account id of the sender
     * @param hashIndex Index of the history entry to squeeze
     * @param receiversRandomSeed Random seed used to determine which history entries
     * to leave out of the squeeze (by hashing them)
     */
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

    /**
     * @notice Withdrawing all funds from the system should never revert
     */
    function testWithdrawAllTokensShouldNotRevert() public heavy {
        try
            EchidnaSqueezeTests(address(this)).testWithdrawAllTokens()
        {} catch {
            assert(false);
        }
    }
}
