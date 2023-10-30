// SPDX-License-Identifier: MIT

import "./EchidnaSetup.sol";
import "./Debugger.sol";

contract EchidnaStorage is EchidnaSetup {
    error DuplicateError();

    mapping(address => StreamReceiver[]) internal userToStreamReceivers;
    mapping(address => StreamsHistory[]) internal userToStreamsHistory;

    function updateStreamReceivers(
        address sender,
        StreamReceiver[] memory unsortedReceivers
    ) internal {
        StreamReceiver[] memory receivers = bubbleSortStreamReceivers(
            unsortedReceivers
        );

        delete userToStreamReceivers[sender];
        for (uint256 i = 0; i < receivers.length; i++) {
            userToStreamReceivers[sender].push(receivers[i]);
        }

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
    }

    function getStreamReceivers(address sender)
        internal
        returns (StreamReceiver[] memory)
    {
        return userToStreamReceivers[sender];
    }

    function getStreamsHistory(address sender)
        internal
        returns (StreamsHistory[] memory)
    {
        return userToStreamsHistory[sender];
    }

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

    function getDripsAccountId(address account) internal returns (uint256) {
        if (ADDRESS_TO_DRIPS_ACCOUNT_ID[account] == 0) {
            ADDRESS_TO_DRIPS_ACCOUNT_ID[account] = driver.calcAccountId(
                account
            );
        }
        return ADDRESS_TO_DRIPS_ACCOUNT_ID[account];
    }
}
