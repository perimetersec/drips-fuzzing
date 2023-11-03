// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/echidna/Echidna.sol";

contract EchidnaToFoundryTest is Test, Echidna {
    function setUp() public {
        console.log("setUp");
    }

    function testDebugHistoryHashes() public {
        uint8 receiverAccId = 0;
        uint8 senderAccId = 64;

        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);
        uint256 receiverDripsAccId = getDripsAccountId(receiver);
        uint256 senderDripsAccId = getDripsAccountId(sender);

        addStream(senderAccId, receiverAccId, 1e18, 0, 0, 10e18);
        addStream(senderAccId, receiverAccId, 2e18, 0, 0, 10e18);
        addStream(senderAccId, receiverAccId, 3e18, 0, 0, 10e18);

        StreamsHistory[] memory historyStructs = getStreamsHistory(sender);
        bytes32[] memory historyHashes = getStreamsHistoryHashes(sender);

        require(historyStructs.length == 3);

        bytes32 historyHash = historyHashes[1];
        StreamsHistory[] memory history = new StreamsHistory[](1);
        history[0] = historyStructs[2];

        drips.squeezeStreams(
            receiverDripsAccId,
            token,
            senderDripsAccId,
            historyHash,
            history
        );
    }
}
