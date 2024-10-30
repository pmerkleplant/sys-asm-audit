// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {Geas} from "./Geas.sol";

address constant addr = address(0xcafe);
address constant sysaddr = address(0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);

contract ExecutionHashTest is Test {
    function setUp() public {
        vm.etch(addr, Geas.compile("src/execution_hash/main.eas"));
    }

    // -- sysaddr --

    function testFuzz_sysaddr_GasCost(bytes32 root) public {
        vm.assume(root != 0);

        bool ok;
        bytes memory data;

        vm.prank(sysaddr);
        vm.startSnapshotGas("set");
        (ok, data) = addr.call(abi.encodePacked(root));
        uint gasUsage = vm.stopSnapshotGas();
        assertTrue(ok);
        assertEq(data.length, 0);

        // Gas costs for non-zero root is ~25k.
        assertEq(gasUsage, 25_078);
    }

    // -- Brute Force --

    // Note that you may need to add --memory-limit <big number> to the forge t
    // command to circumvent OOG errors.
    uint force = 10_000;
    uint lookback = 5;
    uint lookforward = 5;
    uint buflen = 5; // TODO: Update to smaller number here and in main.eas for easier testing.
    function test_BruteForce(uint number) public {
        vm.assume(number > lookback + 1);
        vm.assume(number < type(uint224).max);

        // Start at random block.
        vm.roll(number);

        bool ok;
        bytes memory data;

        // IMPORTANT: Let buffer be full first.
        for (uint i; i < buflen; i++) {
            // sysaddr pushes hash of previous block.
            uint root = block.number - 1; // Let hash = block pushed for easier debugging.
            vm.prank(sysaddr);
            (ok, data) = addr.call(abi.encodePacked(root));
            assertTrue(ok);
            assertEq(data.length, 0);

            vm.roll(block.number + 1);
        }

        for (uint i; i < force; i++) {
            // sysaddr pushes hash of previous block.
            uint root = block.number - 1; // Let hash = block pushed for easier debugging.
            vm.prank(sysaddr);
            (ok, data) = addr.call(abi.encodePacked(root));
            assertTrue(ok);
            assertEq(data.length, 0);

            // Read buflen - 1 elements, ie range [block.number - 1 - (buflen - 1), block.number - 1]
            uint counter;
            for (uint j; j < buflen; j++) {
                uint request = block.number - 1 - j;
                (ok, data) = addr.call(abi.encodePacked(request));
                assertTrue(ok);
                assertEq(data.length, 32);

                // Verify hash is correct.
                assertEq(request, abi.decode(data, (uint)));

                counter++;
            }
            // Verify (for dummies), that we read buflen elements.
            assertEq(counter, buflen);

            // Reading current or future blocks fails.
            for (uint j; j < lookforward; j++) {
                uint request = block.number + j;
                (ok, data) = addr.call(abi.encodePacked(request));
                assertFalse(ok);
                assertEq(data.length, 0);
            }

            // Reading blocks older than block.number - 1 - (buflen - 1) fails.
            for (uint j; j < lookback; j++) {
                uint request = block.number - 1 - (buflen - 1) - 1 - j;
                (ok, data) = addr.call(abi.encodePacked(request));
                assertFalse(ok);
                assertEq(data.length, 0);
            }

            // Reading zero fails.
            (ok, data) = addr.call(abi.encodePacked(uint(0)));
            assertFalse(ok);
            assertEq(data.length, 0);

            // Let there be a new block.
            vm.roll(block.number + 1);
        }
    }
}
