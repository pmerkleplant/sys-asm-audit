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

    // @audit Breaks implicit invariant of only increasing fee!
    function test_NotDecreasing() public pure {
        // Eventhough we get an overflow at ~2.8k, the result is still only
        // increasing.
        uint force = 10_000;
        uint prev;
        uint biggest = type(uint).max;
        for (uint i; i < force; i++) {
            uint cur = fakeExpo(i);

            if (i == 2892) {
                biggest = cur;
            }

            if (cur > biggest) {

            //if (prev > cur) {
                console.log("biggest", biggest);
                console.log("prev", prev);
                console.log("cur", cur);
                console.log("i", i);
                console.log("-------------");
            }
            //assertTrue(prev <= cur);
            prev = cur;
        }
        assertTrue(false);
    }

    function test_Plot() public pure {
        for (uint i; i < 10_000; i++) {
            uint cur = fakeExpo(i);
            console.log(cur);
        }
        assertTrue(false);
    }

    function test_Overflow() public {
        console.log(fakeExpo(2998));

        // Does not overflow.
        fakeExpoChecked(2892);

        // Overflows uint256.
        vm.expectRevert();
        fakeExpoChecked(2893);
    }

    function test_EquivalenceSolidity(uint excess) public {
        vm.assume(excess < 100_000);

        uint want = fakeExpo(excess);

        (bool ok, bytes memory data) = addr.call(abi.encodePacked(excess));
        assertTrue(ok);

        uint got = abi.decode(data, (uint));

        assertEq(got, want);
    }

    // @audit Spec is off!
    // Note that uv is used.
    function test_EquivalenceSpec(uint excess) public {
        vm.assume(excess < 100_000);

        string[] memory args = new string[](4);
        args[0] = "uv";
        args[1] = "run";
        args[2] = "scripts/fake_expo.py";
        args[3] = vm.toString(excess);
        uint want = abi.decode(vm.ffi(args), (uint));

        (bool ok, bytes memory data) = addr.call(abi.encodePacked(excess));
        assertTrue(ok);

        uint got = abi.decode(data, (uint));

        if (excess > 2892) {
            assertNotEq(want, got);
        } else {
            assertEq(want, got);
        }
    }

    // Note that uv is used.
    function test_EquivalenceSpecBoundaries() public {
        {
        // <= 2892
        string[] memory args = new string[](4);
        args[0] = "uv";
        args[1] = "run";
        args[2] = "scripts/fake_expo.py";
        args[3] = vm.toString(uint(2892));
        uint want = abi.decode(vm.ffi(args), (uint));

        (bool ok, bytes memory data) = addr.call(abi.encodePacked(uint(2892)));
        assertTrue(ok);

        uint got = abi.decode(data, (uint));
        assertEq(want, got);
        }

        {
        // > 2892
        string[] memory args = new string[](4);
        args[0] = "uv";
        args[1] = "run";
        args[2] = "scripts/fake_expo.py";
        args[3] = vm.toString(uint(2893));
        uint want = abi.decode(vm.ffi(args), (uint));

        (bool ok, bytes memory data) = addr.call(abi.encodePacked(uint(2893)));
        assertTrue(ok);

        uint got = abi.decode(data, (uint));
        assertNotEq(want, got);
        }
    }
}

