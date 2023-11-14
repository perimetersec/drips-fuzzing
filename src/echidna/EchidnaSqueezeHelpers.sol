// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";
import "./EchidnaBasicHelpers.sol";

contract EchidnaSqueezeHelpers is EchidnaBase, EchidnaBasicHelpers {
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

    function squeezeToSelf(uint8 targetAccId) public {
        squeezeWithDefaultHistory(targetAccId, targetAccId);
    }

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
