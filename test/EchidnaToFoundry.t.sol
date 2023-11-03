// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/echidna/Echidna.sol";

contract EchidnaToFoundryTest is Test, Echidna {
    function setUp() public {
        console.log("setUp");
    }

    function testDebugHistoryHashes() public // uint8 receiverAccId,
    // uint8 senderAccId,
    // uint256 hashIndex
    {
        uint8 receiverAccId = 0;
        uint8 senderAccId = 64;
        uint256 hashIndex = 123;
        
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);
        uint256 receiverDripsAccId = getDripsAccountId(receiver);
        uint256 senderDripsAccId = getDripsAccountId(sender);

        addStream(senderAccId, receiverAccId, 1e18, 0, 0, 10e18);
        addStream(senderAccId, receiverAccId, 2e18, 0, 0, 10e18);
        addStream(senderAccId, receiverAccId, 3e18, 0, 0, 10e18);

        StreamsHistory[] memory historyStructs = getStreamsHistory(sender);
        bytes32[] memory historyHashes = getStreamsHistoryHashes(sender);

        require(historyStructs.length >= 2);

        hashIndex = hashIndex % (historyHashes.length - 1);

        bytes32 historyHash = historyHashes[hashIndex];

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
            console.log("squeeze succeeded");
            // assert(false);
        } catch {
            Debugger.log("squeeze failed");
            console.log("squeeze failed");
            assert(false);
        }
    }
}
