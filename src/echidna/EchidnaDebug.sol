// SPDX-License-Identifier: MIT

import "./EchidnaHelperStreams.sol";
import "./Debugger.sol";

contract EchidnaDebug is EchidnaHelperStreams {
    function debugSqueezeWithHistoryHash(
        uint8 receiverAccId,
        uint8 senderAccId,
        uint256 hashIndex
    ) public {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);
        uint256 receiverDripsAccId = getDripsAccountId(receiver);
        uint256 senderDripsAccId = getDripsAccountId(sender);

        StreamsHistory[] memory historyStructs = getStreamsHistory(sender);
        bytes32[] memory historyHashes = getStreamsHistoryHashes(sender);

        // having a hashed history requires at least 2 history entries
        require(historyStructs.length >= 2);

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

        try
            drips.squeezeStreams(
                receiverDripsAccId,
                token,
                senderDripsAccId,
                historyHash,
                history
            )
        {
            Debugger.log("squeeze succeeded");
            // assert(false);
        } catch {
            Debugger.log("squeeze failed");
            assert(false);
        }
    }
}
