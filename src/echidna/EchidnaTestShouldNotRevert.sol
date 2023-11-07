// SPDX-License-Identifier: MIT

import "./EchidnaTestSqueeze.sol";
import "./Debugger.sol";

contract EchidnaTestShouldNotRevert is EchidnaTestSqueeze {
    ///@notice Giving an amount `<=` token balance should never revert
    function testGiveShouldNotRevert(
        uint8 fromAccId,
        uint8 toAccId,
        uint128 amount
    ) public {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        uint256 toDripsAccId = getDripsAccountId(to);

        require(amount <= token.balanceOf(from));

        hevm.prank(from);
        try driver.give(toDripsAccId, token, amount) {} catch {
            assert(false);
        }
    }

    ///@notice Squeezing should never revert
    function testSqueezeWithDefaultHistoryShouldNotRevert(
        uint8 receiverAccId,
        uint8 senderAccId
    ) public {
        try
            EchidnaHelper(address(this)).squeezeWithDefaultHistory(
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
            EchidnaHelper(address(this)).squeezeWithFuzzedHistory(
                receiverAccId,
                senderAccId,
                hashIndex,
                receiversRandomSeed
            )
        {} catch {
            assert(false);
        }
    }

    ///@notice Receiving streams should never revert
    function testReceiveStreamsShouldNotRevert(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        try
            drips.receiveStreams(targetDripsAccId, token, type(uint32).max)
        {} catch {
            assert(false);
        }
    }

    ///@notice Splitting should never revert
    function testSplitShouldNotRevert(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        try
            drips.split(targetDripsAccId, token, new SplitsReceiver[](0))
        {} catch {
            assert(false);
        }
    }

    ///@notice Collecting should never revert
    function testCollectShouldNotRevert(uint8 fromAccId, uint8 toAccId) public {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        hevm.prank(from);
        try driver.collect(token, to) {} catch {
            assert(false);
        }
    }

    ///@notice Setting streams with sane defaults should not revert
    function testSetStreamsShouldNotRevert(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) public {
        try
            EchidnaHelperStreams(address(this)).setStreamsWithClamping(
                fromAccId,
                toAccId,
                amountPerSec,
                startTime,
                duration,
                balanceDelta
            )
        {} catch {
            assert(false);
        }
    }

    ///@notice Adding streams with sane defaults should not revert
    function testAddStreamShouldNotRevert(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) public {
        try
            EchidnaHelperStreams(address(this)).addStreamWithClamping(
                fromAccId,
                toAccId,
                amountPerSec,
                startTime,
                duration,
                balanceDelta
            )
        returns (int128 realBalanceDelta) {} catch (bytes memory reason) {
            bytes4 errorSelector = bytes4(keccak256(bytes("DuplicateError()")));
            if (errorSelector == EchidnaStorage.DuplicateError.selector) {
                // ignore this case, it means we tried to add a duplicate stream
            } else {
                assert(false);
            }
        }
    }

    ///@notice Removing streams should not revert
    function testRemoveStreamShouldNotRevert(
        uint8 targetAccId,
        uint256 indexSeed
    ) public {
        address target = getAccount(targetAccId);
        require(getStreamReceivers(target).length > 0);

        try
            EchidnaHelperStreams(address(this)).removeStream(
                targetAccId,
                indexSeed
            )
        {} catch {
            assert(false);
        }
    }

    ///@notice Updating stream balance with sane defaults should not revert
    function testSetStreamBalanceShouldNotRevert(
        uint8 targetAccId,
        int128 balanceDelta
    ) public {
        try
            EchidnaHelperStreams(address(this)).setStreamBalanceWithClamping(
                targetAccId,
                balanceDelta
            )
        {} catch {
            assert(false);
        }
    }

    ///@notice Withdrawing all stream balance should not revert
    function testSetStreamBalanceWithdrawAllShouldNotRevert(uint8 targetAccId)
        public
    {
        try
            EchidnaHelperStreams(address(this)).setStreamBalanceWithdrawAll(
                targetAccId
            )
        {} catch {
            assert(false);
        }
    }

    function testWithdrawAllTokensShouldNotRevert() public heavy {
        try EchidnaTest(address(this)).testWithdrawAllTokens() {} catch {
            assert(false);
        }
    }
}
