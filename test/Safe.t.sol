// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {SentrixSafe} from "../contracts/SentrixSafe.sol";

contract SafeTest is Test {
    SentrixSafe safe;
    uint256 pk1 = 0xa11ce;
    uint256 pk2 = 0xb0b;
    uint256 pk3 = 0xcafe;
    address owner1;
    address owner2;
    address owner3;

    function setUp() public {
        owner1 = vm.addr(pk1);
        owner2 = vm.addr(pk2);
        owner3 = vm.addr(pk3);

        // Sort owners ascending so signature loop's strict-ascending check
        // can be satisfied with sigs sorted by signer address.
        address[] memory sorted = _sort3(owner1, owner2, owner3);
        owner1 = sorted[0];
        owner2 = sorted[1];
        owner3 = sorted[2];

        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        safe = new SentrixSafe(owners, 2);

        vm.deal(address(safe), 10 ether);
    }

    function test_constructor_sets_owners_and_threshold() public {
        assertEq(safe.threshold(), 2);
        assertTrue(safe.isOwner(owner1));
        assertTrue(safe.isOwner(owner2));
        assertTrue(safe.isOwner(owner3));
        assertEq(safe.getOwners().length, 3);
    }

    function test_reverts_on_zero_threshold() public {
        address[] memory owners = new address[](1);
        owners[0] = owner1;
        vm.expectRevert(bytes("Safe: invalid threshold"));
        new SentrixSafe(owners, 0);
    }

    function test_reverts_on_threshold_exceeds_owners() public {
        address[] memory owners = new address[](1);
        owners[0] = owner1;
        vm.expectRevert(bytes("Safe: invalid threshold"));
        new SentrixSafe(owners, 2);
    }

    function test_reverts_on_duplicate_owner() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner1;
        vm.expectRevert(bytes("Safe: duplicate owner"));
        new SentrixSafe(owners, 1);
    }

    // Helpers
    function _sort3(address a, address b, address c) internal pure returns (address[] memory) {
        address[] memory arr = new address[](3);
        arr[0] = a; arr[1] = b; arr[2] = c;
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = i + 1; j < 3; j++) {
                if (arr[i] > arr[j]) { (arr[i], arr[j]) = (arr[j], arr[i]); }
            }
        }
        return arr;
    }
}
