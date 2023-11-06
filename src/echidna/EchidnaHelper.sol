// SPDX-License-Identifier: MIT

import "./EchidnaAccounting.sol";
import "./Debugger.sol";

contract EchidnaHelper is EchidnaAccounting {
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

        uint128 MIN_AMOUNT = 1000;
        uint128 MAX_AMOUNT = uint128(token.balanceOf(from));
        uint128 clampedAmount = MIN_AMOUNT +
            (amount % (MAX_AMOUNT - MIN_AMOUNT + 1));

        give(fromAccId, toAccId, clampedAmount);
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
    ) internal {
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

        _squeeze(receiverAccId, senderAccId, historyHash, history);
    }

    function squeezeWithFuzzedHistory(
        uint8 receiverAccId,
        uint8 senderAccId,
        uint256 hashIndex,
        bytes32 receiversRandomSeed
    ) external {
        _squeezeWithFuzzedHistory(
            receiverAccId,
            senderAccId,
            hashIndex,
            receiversRandomSeed
        );
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

    function getFuzzedStreamsHistory(
        uint8 targetAccId,
        uint256 hashIndex,
        bytes32 receiversRandomSeed
    ) public returns (bytes32, StreamsHistory[] memory) {
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
