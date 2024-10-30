// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {Geas} from "./Geas.sol";

address constant addr = address(0xcafe);
address constant sysaddr = address(0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);

uint constant MAX_EXCESS = 2892;
uint constant MAX_PER_BLOCK = 16;
uint constant TARGET_PER_BLOCK = 2;
uint constant RECORD_SIZE = 76;

contract WithdrawalsTest is Test {
    function setUp() public {
        vm.etch(addr, Geas.compile("src/withdrawals/main.eas"));
    }

    function testFuzz_LittleEndianLoop(uint64 amt) public pure {
        uint want = toLittleEndian(amt);
        uint got = toLittleEndian_Loop(amt);

        assertEq(want, got);
    }

    // -- sysaddr --

    function testFuzz_sysaddr_get(uint excess, uint counter, uint head, uint tail) public {
        // --------------------------------
        // -- Set random but valid state
        // --------------------------------
        vm.setArbitraryStorage(addr);

        // Store excess at slot 0.
        // Note to allow excess to be inhibitor.
        vm.assume(excess <= MAX_EXCESS || excess == type(uint).max);
        vm.store(addr, 0, bytes32(excess));

        // Store counter at slot 1.
        //
        // IMPORTANT: If inhibitor set, counter MUST be zero.
        if (excess == type(uint).max) {
            counter = 0;
        } else {
            vm.assume(counter <= 1_000_000); // Stay reasonable.
        }
        vm.store(addr, bytes32(uint(1)), bytes32(counter));

        // Store head and tail at slot 2 and 3.
        vm.assume(head < 100_000);
        vm.assume(tail < 200_000);
        vm.assume(head <= tail);
        vm.store(addr, bytes32(uint(2)), bytes32(head));
        vm.store(addr, bytes32(uint(3)), bytes32(tail));

        console.log("Initial State");
        console.log(string.concat("head=", vm.toString(head), ", tail=", vm.toString(tail)));
        console.log(string.concat("excess=", vm.toString(excess), ", counter=", vm.toString(counter)));

        // --------------------------------
        // -- Compute expected result and new state
        // --------------------------------

        // Compute number of elements in queue.
        uint count = tail - head;
        if (count > MAX_PER_BLOCK) {
            count = MAX_PER_BLOCK;
        }

        // Compute new_head = head + count.
        uint new_head = head + count;
        assertTrue(new_head <= tail);

        // If new_head equals tail, ie queue is emptied, reset both to zero.
        uint new_tail = tail;
        if (new_head == tail) {
            new_head = 0;
            new_tail = 0;
        }

        // Compute new excess.
        uint new_excess;
        if (excess == type(uint).max) {
            // Excess is inhibitor and must be zeroed.
            new_excess = 0;
        } else {
            if (excess + counter > TARGET_PER_BLOCK) {
                new_excess = (counter + excess) - TARGET_PER_BLOCK;
            } else {
                new_excess = 0;
            }
        }

        console.log("Expected State");
        console.log(string.concat("head=", vm.toString(new_head), ", tail=", vm.toString(new_tail)));
        console.log(string.concat("excess=", vm.toString(new_excess), ", counter=0"));

        // --------------------------------
        // -- Execute sysaddr call
        // --------------------------------

        bool ok;
        bytes memory data;

        vm.prank(sysaddr);
        (ok, data) = addr.call(hex"");
        assertTrue(ok);

        // --------------------------------
        // -- Verify return values and new state
        // --------------------------------
        bytes32 slot;

        // -- Verify return data --
        //
        // Verify size of return data.
        assertEq(data.length, RECORD_SIZE * count);
        if (data.length != 0) {
            // Verify content.
            bytes memory read_want;
            uint cur = head;
            for (uint i; i < count; i++) {
                cur = head + i;

                // Note to remove prefix of first slot (address) to truncate to 20 bytes.
                slot = vm.load(addr, bytes32(cur * 3 + 4));
                read_want = bytes.concat(read_want, bytes20(uint160(uint(slot))));

                slot = vm.load(addr, bytes32(cur * 3 + 4 + 1));
                read_want = bytes.concat(read_want, slot);

                // Note to remove suffix of last slot (pk2++amt) to truncate to 24 bytes.
                //
                // IMPORTANT: amount is little-endian encoded.
                slot = vm.load(addr, bytes32(cur * 3 + 4 + 2));
                // Append the pk2 bytes.
                read_want = bytes.concat(read_want, bytes16(uint128(uint(slot >> 128))));
                // Get the amt bytes.
                uint64 amt = uint64(uint(slot >> 64));
                uint64 amt_little_endian = toLittleEndian(amt);

                read_want = bytes.concat(read_want, bytes8(amt_little_endian));
            }
            assertEq(data.length, read_want.length);
            assertEq(data, read_want);
        }

        // -- Verify storage slots --
        // Verify excess is correct.
        slot = vm.load(addr, bytes32(uint(0)));
        assertEq(uint(slot), new_excess);

        // Verify counter is zero.
        slot = vm.load(addr, bytes32(uint(1)));
        assertEq(uint(slot), 0);

        // Verify head and tail are correct.
        slot = vm.load(addr, bytes32(uint(2)));
        assertEq(uint(slot), new_head);
        slot = vm.load(addr, bytes32(uint(3)));
        assertEq(uint(slot), new_tail);
    }

    // -- user::get --

    function testFuzz_user_get(address user, uint excess) public {
        // Randomize storage. We'll overwrite the slots we need.
        vm.setArbitraryStorage(addr);

        vm.assume(user != sysaddr);

        // Store excess at slot 0.
        vm.store(addr, 0, bytes32(excess));

        bool ok;
        bytes memory data;

        // Using call.
        vm.prank(user);
        (ok, data) = addr.call{value: 0}(hex"");
        assertTrue(ok);
        assertEq(data.length, 32);
        assertEq(excess, abi.decode(data, (uint)));

        // Using staticcall.
        vm.prank(user);
        (ok, data) = addr.staticcall(hex"");
        assertTrue(ok);
        assertEq(data.length, 32);
        assertEq(excess, abi.decode(data, (uint)));
    }

    function testFuzz_user_get_GasCost(address user, uint excess) public {
        // Randomize storage. We'll overwrite the slots we need.
        vm.setArbitraryStorage(addr);

        vm.assume(user != sysaddr);

        // Store excess at slot 0.
        vm.store(addr, 0, bytes32(excess));

        bool ok;
        bytes memory data;

        vm.prank(user);
        vm.startSnapshotGas("get");
        (ok, data) = addr.call{value: 0}(hex"");
        uint gasUsage = vm.stopSnapshotGas();
        assertTrue(ok);
        assertEq(data.length, 32);
        assertEq(excess, abi.decode(data, (uint)));

        // Gas cost is ~400.
        assertEq(gasUsage, 401);
    }

    function testFuzz_user_get_IsNonPayable(address user, uint value) public {
        // Randomize storage. We'll overwrite the slots we need.
        vm.setArbitraryStorage(addr);

        vm.assume(user != sysaddr);
        vm.assume(value != 0);
        vm.deal(user, value);

        bool ok;
        bytes memory data;

        vm.prank(user);
        (ok, data) = addr.call{value: value}(hex"");
        assertFalse(ok);
        assertEq(data.length, 0);
    }

    function testFuzz_user_get_OnlyIfNoCalldata(address user, uint excess, bytes memory payload) public {
        // Randomize storage. We'll overwrite the slots we need.
        vm.setArbitraryStorage(addr);

        vm.assume(user != sysaddr);
        vm.assume(payload.length != 0);

        // Store excess at slot 0.
        vm.store(addr, 0, bytes32(excess));

        bool ok;
        bytes memory data;

        // Note that adding a withdrawal requests costs a non-zero fee.
        // Therefore, expect call to always revert.
        vm.prank(user);
        (ok, data) = addr.call{value: 0}(payload);
        assertFalse(ok);
        assertEq(data.length, 0);

        vm.prank(user);
        (ok, data) = addr.staticcall(payload);
        assertFalse(ok);
        assertEq(data.length, 0);
    }

    // -- user::set --

    function testFuzz_user_set_ok(address user, uint excess, uint counter, uint tail) public {
        // Randomize storage. We'll overwrite the slots we need.
        vm.setArbitraryStorage(addr);

        vm.assume(user != sysaddr);
        vm.assume(excess <= MAX_EXCESS);

        vm.deal(user, type(uint).max);

        // Store excess at slot 0.
        vm.store(addr, 0, bytes32(excess));

        // Store counter at slot 1.
        vm.assume(counter < type(uint).max);
        vm.store(addr, bytes32(uint(1)), bytes32(counter));

        // Note to stay reasonable.
        vm.assume(tail < 10_000);

        // Store tail at slot 3.
        vm.store(addr, bytes32(uint(3)), bytes32(tail));

        // 56 total size.
        bytes memory payload = bytes.concat(
            hex"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            hex"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        );
        bool ok;
        bytes memory data;

        vm.prank(user);
        vm.startSnapshotGas("set");
        (ok, data) = addr.call{value: type(uint).max}(payload);
        uint gasUsage = vm.stopSnapshotGas();
        assertTrue(ok);
        assertEq(data.length, 0);

        console.log("Gas used", gasUsage);

        // Verify data got written at correct offsets:
        uint start = (tail * 3) + 4;
        // uint end = start + 3;
        bytes32 slot;
        slot = vm.load(addr, bytes32(start));
        assertEq(slot, bytes32(uint(uint160(user))));
        slot = vm.load(addr, bytes32(start+1));
        assertEq(slot, hex"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        slot = vm.load(addr, bytes32(start+2));
        assertEq(slot, hex"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");

        // Verify that counter got increased.
        slot = vm.load(addr, bytes32(uint(1)));
        assertEq(slot, bytes32(counter + 1));
    }

    function testFuzz_user_set_FailsIfInputSizeInvalid(address user, bytes memory payload) public {
        // Randomize storage. We'll overwrite the slots we need.
        vm.setArbitraryStorage(addr);

        vm.assume(user != sysaddr);
        vm.assume(payload.length != 56);

        vm.deal(user, type(uint).max);

        bool ok;
        bytes memory data;

        vm.prank(user);
        (ok, data) = addr.call{value: type(uint).max}(payload);
        assertFalse(ok);
        assertEq(data.length, 0);
    }

    function testFuzz_user_set_FailsIfInhibitorSet(address user) public {
        // Randomize storage. We'll overwrite the slots we need.
        vm.setArbitraryStorage(addr);

        vm.assume(user != sysaddr);

        vm.deal(user, type(uint).max);

        // Store excess of type(uint).max at slot 0.
        vm.store(addr, 0, bytes32(type(uint).max));

        bytes memory payload = bytes.concat(bytes32(0), bytes24(0)); // 56 total size
        bool ok;
        bytes memory data;

        vm.prank(user);
        (ok, data) = addr.call{value: type(uint).max}(payload);
        assertFalse(ok);
        assertEq(data.length, 0);
    }

    function testFuzz_user_set_FailsIfFeeNotCovered(address user, uint excess, uint value) public {
        // Randomize storage. We'll overwrite the slots we need.
        vm.setArbitraryStorage(addr);

        vm.assume(user != sysaddr);
        vm.assume(excess <= MAX_EXCESS);

        uint fee = fakeExpo(excess);
        vm.assume(value < fee);

        vm.deal(user, type(uint).max);

        // Store excess at slot 0.
        vm.store(addr, 0, bytes32(excess));

        bytes memory payload = bytes.concat(bytes32(0), bytes24(0)); // 56 total size
        bool ok;
        bytes memory data;

        vm.prank(user);
        (ok, data) = addr.call{value: value}(payload);
        assertFalse(ok);
        assertEq(data.length, 0);
    }
}

function fakeExpo(uint numerator) pure returns (uint) {
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

function toLittleEndian(uint64 amt) pure returns (uint64) {
    return ((amt >> 56) & 0x00000000000000FF) |
           ((amt >> 40) & 0x000000000000FF00) |
           ((amt >> 24) & 0x0000000000FF0000) |
           ((amt >> 8)  & 0x00000000FF000000) |
           ((amt << 8)  & 0x000000FF00000000) |
           ((amt << 24) & 0x0000FF0000000000) |
           ((amt << 40) & 0x00FF000000000000) |
           ((amt << 56) & 0xFF00000000000000);
}

function toLittleEndian_Loop(uint64 amt) pure returns (uint64) {
    // Simulate memory via uint8[8] array.
    uint8[] memory result = new uint8[](8);

    uint len = 8;
    for (uint i; i < len; i++) {
        result[i] = uint8(amt >> (len-1-i)*8);
    }

    amt = 0;
    for (uint i; i < len; i++) {
        amt |= uint64(uint(result[i]) << i*8);
    }

    return amt;
}
