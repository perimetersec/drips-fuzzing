// SPDX-License-Identifier: MIT

import "./EchidnaStreams.sol";

contract EchidnaSqueeze is EchidnaStreams {
    function testWithdrawAllTokensShouldNotRevert() public heavy {
        try EchidnaSqueeze(address(this)).testWithdrawAllTokens() {} catch {
            assert(false);
        }
    }

    ///@notice Squeezing should never revert
    function testSqueezeWithDefaultHistoryShouldNotRevert(
        uint8 receiverAccId,
        uint8 senderAccId
    ) public {
        try
            EchidnaSqueeze(address(this)).squeezeWithDefaultHistory(
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
            EchidnaSqueeze(address(this)).squeezeWithFuzzedHistory(
                receiverAccId,
                senderAccId,
                hashIndex,
                receiversRandomSeed
            )
        {} catch {
            assert(false);
        }
    }

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

    function testWithdrawAllTokens() external heavy {
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

        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);

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

    function _squeeze(
        uint8 receiverAccId,
        uint8 senderAccId,
        bytes32 historyHash,
        StreamsHistory[] memory history
    ) internal returns (uint128) {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);
        uint256 receiverDripsAccId = getDripsAccountId(receiver);
        uint256 senderDripsAccId = getDripsAccountId(sender);

        uint128 amount = drips.squeezeStreams(
            receiverDripsAccId,
            token,
            senderDripsAccId,
            historyHash,
            history
        );

        return amount;
    }

    function _squeezeWithDefaultHistory(uint8 receiverAccId, uint8 senderAccId)
        internal
        returns (uint128)
    {
        return
            _squeeze(
                receiverAccId,
                senderAccId,
                bytes32(0),
                getStreamsHistory(getAccount(senderAccId))
            );
    }

    function squeezeWithDefaultHistory(uint8 receiverAccId, uint8 senderAccId)
        external
        returns (uint128)
    {
        return _squeezeWithDefaultHistory(receiverAccId, senderAccId);
    }

    function squeezeToSelf(uint8 targetAccId) public {
        _squeezeWithDefaultHistory(targetAccId, targetAccId);
    }

    function squeezeAllSenders(uint8 targetAccId) public {
        _squeezeWithDefaultHistory(
            targetAccId,
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]
        );
        _squeezeWithDefaultHistory(
            targetAccId,
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]
        );
        _squeezeWithDefaultHistory(
            targetAccId,
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]
        );
        _squeezeWithDefaultHistory(
            targetAccId,
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]
        );
    }

    function _squeezeWithFuzzedHistory(
        uint8 receiverAccId,
        uint8 senderAccId,
        uint256 hashIndex,
        bytes32 receiversRandomSeed
    ) internal returns (uint128) {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);
        uint256 receiverDripsAccId = getDripsAccountId(receiver);
        uint256 senderDripsAccId = getDripsAccountId(sender);

        (
            bytes32 historyHash,
            StreamsHistory[] memory history
        ) = getFuzzedStreamsHistory(
                senderAccId,
                hashIndex,
                receiversRandomSeed
            );

        return _squeeze(receiverAccId, senderAccId, historyHash, history);
    }

    function squeezeWithFuzzedHistory(
        uint8 receiverAccId,
        uint8 senderAccId,
        uint256 hashIndex,
        bytes32 receiversRandomSeed
    ) external returns (uint128) {
        return
            _squeezeWithFuzzedHistory(
                receiverAccId,
                senderAccId,
                hashIndex,
                receiversRandomSeed
            );
    }

    function squeezeAllAndReceiveAndSplitAndCollectToSelf(uint8 targetAccId)
        public
    {
        squeezeAllSenders(targetAccId);
        receiveStreamsSplitAndCollectToSelf(targetAccId);
    }

    function getFuzzedStreamsHistory(
        uint8 targetAccId,
        uint256 hashIndex,
        bytes32 receiversRandomSeed
    ) internal returns (bytes32, StreamsHistory[] memory) {
        address target = getAccount(targetAccId);

        // get the history structs and hashes
        StreamsHistory[] memory historyStructs = getStreamsHistory(target);
        bytes32[] memory historyHashes = getStreamsHistoryHashes(target);

        // having a hashed history requires at least 2 history entries
        require(historyStructs.length >= 2, "need at least 2 history entries");

        // hashIndex must be within bounds and cant be the last entry
        hashIndex = hashIndex % (historyHashes.length - 1);

        // get the history hash at the index
        bytes32 historyHash = historyHashes[hashIndex];

        // create a history array with all entries after the hashIndex
        StreamsHistory[] memory history = new StreamsHistory[](
            historyStructs.length - 1 - hashIndex
        );
        for (uint256 i = hashIndex + 1; i < historyStructs.length; i++) {
            history[i - hashIndex - 1] = historyStructs[i];
        }

        // hash receivers based on 'receiversRandomSeed'
        for (uint256 i = 0; i < history.length; i++) {
            receiversRandomSeed = keccak256(bytes.concat(receiversRandomSeed));
            bool hashBool = (uint256(receiversRandomSeed) % 2) == 0
                ? false
                : true;

            if (hashBool) {
                history[i].streamsHash = drips.hashStreams(
                    history[i].receivers
                );
                history[i].receivers = new StreamReceiver[](0);
            }
        }

        return (historyHash, history);
    }
}
