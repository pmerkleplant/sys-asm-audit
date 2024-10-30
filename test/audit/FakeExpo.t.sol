// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {Geas} from "./Geas.sol";

address constant addr = address(0xcafe);

contract FakeExpoTest is Test {
    function setUp() public {
        vm.etch(addr, Geas.compile("src/common/fake_expo_audit.eas"));
    }

    // -- Fake Exponential Implementations --

    function fakeExpo(uint numerator) public pure returns (uint) {
        // Copied from contracts.
        uint factor = 1;
        uint denominator = 17;

        unchecked {
            uint i = 1;
            uint output = 0;
            uint numerator_accum = factor * denominator;
            while (numerator_accum > 0) {
                output += numerator_accum;
                numerator_accum = (numerator_accum * numerator) / (denominator * i);
                i += 1;
            }
            return output / denominator;
        }
    }

    function fakeExpoChecked(uint numerator) public pure returns (uint) {
        // Copied from contracts.
        uint factor = 1;
        uint denominator = 17;

        uint i = 1;
        uint output = 0;
        uint numerator_accum = factor * denominator;
        while (numerator_accum > 0) {
            output += numerator_accum;
            numerator_accum = (numerator_accum * numerator) / (denominator * i);
            i += 1;
        }
        return output / denominator;
    }

    // -- Tests --

    function test_Overflow() public {
        // Does not overflow.
        fakeExpoChecked(2892);

        // Overflows uint256.
        vm.expectRevert();
        fakeExpoChecked(2893);
    }

    // Proves that the geas fake_expo functionality is implemented correctly for
    // excess \in [0, 2893).
    function test_Equivalence(uint excess) public {
        // Note that uint256 overflow occurs for excess >= 2893.
        excess = _bound(excess, 0, 2892);

        uint want = fakeExpo(excess);

        (bool ok, bytes memory data) = addr.call(abi.encodePacked(excess));
        assertTrue(ok);

        uint got = abi.decode(data, (uint));

        assertEq(got, want);
    }
}

