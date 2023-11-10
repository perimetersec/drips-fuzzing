// SPDX-License-Identifier: MIT
import "./EchidnaSetup.sol";

/**
 * @title Mixin for storing stream receivers and streams history
 * @author Rappie
 */
contract EchidnaStorage is EchidnaSetup {
    error DuplicateError();

    // Mapping from address to current stream receivers
    mapping(address => StreamReceiver[]) internal userToStreamReceivers;

    // Mappings from address to full streams history and hashes
    mapping(address => StreamsHistory[]) internal userToStreamsHistory;
    mapping(address => bytes32[]) internal userToStreamsHistoryHashes;

    /**
     * @notice Update the stream receivers for a given account.
     * @param sender Account to update
     * @param receivers New stream receivers
     * @dev This function will generate a new hash for the stream receivers,
     * update the stream receivers for the given account, and add a new entry
     * to the streams history and streams history hashes for the given
     * account. This is stored for later use.
     */
    function updateStreamReceivers(
        address sender,
        StreamReceiver[] memory receivers
    ) internal {
        // Hash the new stream receivers
        bytes32 receiversHash = drips.hashStreams(receivers);

        // Update the stream receivers for 'sender'
        delete userToStreamReceivers[sender];
        for (uint256 i = 0; i < receivers.length; i++) {
            userToStreamReceivers[sender].push(receivers[i]);
        }

        // Add a new entry to the streams history
        uint256 nextIndex = userToStreamsHistory[sender].length;
        userToStreamsHistory[sender].push();
        userToStreamsHistory[sender][nextIndex].streamsHash = bytes32(0);
        for (uint256 i = 0; i < receivers.length; i++) {
            userToStreamsHistory[sender][nextIndex].receivers.push(
                receivers[i]
            );
        }
        (, , uint32 updateTime, , uint32 maxEnd) = drips.streamsState(
            getDripsAccountId(sender),
            token
        );
        userToStreamsHistory[sender][nextIndex].updateTime = updateTime;
        userToStreamsHistory[sender][nextIndex].maxEnd = maxEnd;

        // Generate starting hash. If there is no previous history, use 0
        bytes32 startingHash;
        if (nextIndex == 0) {
            startingHash = bytes32(0);
        } else {
            startingHash = userToStreamsHistoryHashes[sender][nextIndex - 1];
        }

        // Add new entry to the streams history hashes
        bytes32 historyHash = drips.hashStreamsHistory(
            startingHash,
            receiversHash,
            updateTime,
            maxEnd
        );
        userToStreamsHistoryHashes[sender].push(historyHash);
    }

    /**
     * @notice Get the stream receivers for a given account.
     * @param sender Account to get stream receivers for
     * @return Stream receivers for the given account
     */
    function getStreamReceivers(address sender)
        internal
        returns (StreamReceiver[] memory)
    {
        return userToStreamReceivers[sender];
    }

    /**
     * @notice Get the streams history for a given account.
     * @param sender Account to get streams history for
     * @return Streams history for the given account
     */
    function getStreamsHistory(address sender)
        internal
        returns (StreamsHistory[] memory)
    {
        return userToStreamsHistory[sender];
    }

    /**
     * @notice Get the streams history hashes for a given account.
     * @param sender Account to get streams history hashes for
     * @return Streams history hashes for the given account
     */
    function getStreamsHistoryHashes(address sender)
        internal
        returns (bytes32[] memory)
    {
        return userToStreamsHistoryHashes[sender];
    }

    /**
     * @notice Sort the stream receivers.
     * @param unsorted Unsorted stream receivers
     * @return Sorted stream receivers
     * @dev This function will sort the stream receivers by account ID,
     * then by config, then by stream ID. It will revert if there are
     * duplicate stream receivers.
     */
    function bubbleSortStreamReceivers(StreamReceiver[] memory unsorted)
        internal
        returns (StreamReceiver[] memory)
    {
        uint256 n = unsorted.length;
        if (n <= 1) return unsorted;

        StreamReceiver[] memory sorted = unsorted;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (bubbleSortStreamReceiverGT(sorted[j], sorted[j + 1])) {
                    StreamReceiver memory temp = sorted[j];
                    sorted[j] = sorted[j + 1];
                    sorted[j + 1] = temp;
                }
            }
        }
        return sorted;
    }

    /**
     * @notice Compare two stream receivers.
     * @param a First stream receiver
     * @param b Second stream receiver
     * @return True if `a` is greater than `b`, false otherwise
     * @dev This function will compare two stream receivers by account ID,
     * then by config. It will revert if there are duplicate stream receivers.
     */
    function bubbleSortStreamReceiverGT(
        StreamReceiver memory a,
        StreamReceiver memory b
    ) internal returns (bool) {
        if (a.accountId != b.accountId) {
            return a.accountId > b.accountId;
        }
        if (StreamConfig.unwrap(a.config) != StreamConfig.unwrap(b.config)) {
            return
                StreamConfig.unwrap(a.config) > StreamConfig.unwrap(b.config);
        }
        revert DuplicateError();
    }

    /**
     * @notice Get the drips account ID for a given address.
     * @param account Address to get drips account ID for
     * @return Drips account ID for the given address
     * @dev Caches the value to increase performance
     */
    function getDripsAccountId(address account) internal returns (uint256) {
        if (ADDRESS_TO_DRIPS_ACCOUNT_ID[account] == 0) {
            ADDRESS_TO_DRIPS_ACCOUNT_ID[account] = driver.calcAccountId(
                account
            );
        }
        return ADDRESS_TO_DRIPS_ACCOUNT_ID[account];
    }
}
