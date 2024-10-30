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

    uint force = 1_000_000;
    function test_BruteForce(uint number) public {
        vm.assume(number < type(uint224).max);

        vm.roll(number);

        bool ok;
        bytes memory data;
        for (uint i; i < force; i++) {
            // sysaddr pushes hash of previous block.
            uint root = block.number - 1; // Let hash = block pushed for easier debugging.
            vm.prank(sysaddr);
            (ok, data) = addr.call(abi.encodePacked(root));
            assertTrue(ok);
            assertEq(data.length, 0);

            // Read 8191 elements, ie range [block.number - 1 - (8191 - 1), block.number - 1]
            for (uint j; j < 8191; j++) {
                uint request = block.number - 1 - i;
                (ok, data) = addr.call(abi.encodePacked(request));
                assertTrue(ok);
                assertEq(data.length, 32);

                // Verify hash is correct.
                assertEq(request, abi.decode(data, (uint)));
            }

            // Reading current or future blocks fails.
            for (uint j; j < 100; j++) {
                uint request = block.number + i;
                (ok, data) = addr.call(abi.encodePacked(request));
                assertFalse(ok);
                assertEq(data.length, 0);
            }

            // Reading blocks older than block.number - 1 - (8191 - 1) fails.
            for (uint j; j < 100; j++) {
                uint request = block.number - 1 - 8191 - i;
            }
        }
    }
}
