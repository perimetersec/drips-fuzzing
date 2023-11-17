// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";
import "./EchidnaBasicHelpers.sol";

/**
 * @title Mixin containing helpers for squeezing
 * @author Rappie
 */
contract EchidnaSqueezeHelpers is EchidnaBase, EchidnaBasicHelpers {
    /**
     * @notice Internal helper function to squeeze streams
     * @param receiverAccId Account id of the receiver
     * @param senderAccId Account id of the sender
     * @param historyHash Hash of the streams history
     * @param history Streams history array
     * @return Amount squeezed
     */
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

    /**
     * @notice Squeeze streams with default history (all StreamHistory entries)
     * @param receiverAccId Account id of the receiver
     * @param senderAccId Account id of the sender
     * @return Amount squeezed
     */
    function squeezeWithDefaultHistory(uint8 receiverAccId, uint8 senderAccId)
        public
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

    /**
     * @notice Squeeze streams with a fuzzed history
     * @param receiverAccId Account id of the receiver
     * @param senderAccId Account id of the sender
     * @param hashIndex Index of the history hash to use
     * @param receiversRandomSeed Random seed used for fuzzing the history
     * @return Amount squeezed
     * @dev This function will use the seed to make random changes to the history.
     * These include changing the starting point of the history, and hashing
     * certain history entries to leave them out of the squeeze.
     */
    function squeezeWithFuzzedHistory(
        uint8 receiverAccId,
        uint8 senderAccId,
        uint256 hashIndex,
        bytes32 receiversRandomSeed
    ) public returns (uint128) {
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

    /**
     * @notice Squeeze streams sent to self
     * @param targetAccId Account id of the sender
     */
    function squeezeToSelf(uint8 targetAccId) public {
        squeezeWithDefaultHistory(targetAccId, targetAccId);
    }

    /**
     * @notice Squeeze streams from all possible senders to target
     * @param targetAccId Account id of the receiver
     * @dev This can be used to test extracting all value from the system
     */
    function squeezeAllSenders(uint8 targetAccId) public {
        squeezeWithDefaultHistory(
            targetAccId,
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]
        );
        squeezeWithDefaultHistory(
            targetAccId,
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]
        );
        squeezeWithDefaultHistory(
            targetAccId,
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]
        );
        squeezeWithDefaultHistory(
            targetAccId,
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]
        );
    }

    /**
     * @notice Squeeze all senders, receive streams, split and collect funds to self
     * @param targetAccId Target account
     * @dev Extra helper that narrows the search space for the fuzzer
     */
    function squeezeAllAndReceiveAndSplitAndCollectToSelf(uint8 targetAccId)
        public
    {
        squeezeAllSenders(targetAccId);
        receiveStreamsSplitAndCollectToSelf(targetAccId);
    }

    /**
     * @notice Helper to create a fuzzed version of a sender's streams history
     * @param targetAccId Account id of the sender
     * @param hashIndex Index of the history entry to be used as the starting point
     * @param receiversRandomSeed Random seed used to determine which history entries
     * to leave out of the squeeze (by hashing them)
     * @return Hash of the history, and the fuzzed streams history array
     */
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
