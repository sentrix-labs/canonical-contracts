// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TokenFactoryV2} from "../contracts/TokenFactoryV2.sol";
import {FactoryTokenV2} from "../contracts/FactoryTokenV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract TokenFactoryV2Test is Test {
    TokenFactoryV2 public factory;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // Default V2 config: 18 decimals, permit + pause enabled.
    uint8 constant DEFAULT_DECIMALS = 18;
    bool constant DEFAULT_PERMIT = true;
    bool constant DEFAULT_PAUSE = true;

    function setUp() public {
        vm.prank(deployer);
        factory = new TokenFactoryV2();
    }

    /// @notice Basic deploy — no cap, no pause disabled.
    function test_deployBasic() public {
        vm.prank(deployer);
        address token = factory.deployToken(
            "Test Token", "TST", DEFAULT_DECIMALS, 1_000_000 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );

        FactoryTokenV2 t = FactoryTokenV2(token);
        assertEq(t.name(), "Test Token");
        assertEq(t.symbol(), "TST");
        assertEq(t.decimals(), DEFAULT_DECIMALS);
        assertEq(t.totalSupply(), 1_000_000 ether);
        assertEq(t.balanceOf(deployer), 1_000_000 ether);
        assertEq(t.owner(), deployer);
        assertFalse(t.isCapped()); // unlimited
        assertFalse(t.paused());
    }

    /// @notice Deploy with custom decimals.
    function test_deployCustomDecimals() public {
        vm.prank(deployer);
        address token = factory.deployToken(
            "Six Decimals", "SIX", 6, 1_000_000, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );

        FactoryTokenV2 t = FactoryTokenV2(token);
        assertEq(t.decimals(), 6);
    }

    /// @notice Deploy with a supply cap.
    function test_deployWithCap() public {
        uint256 cap = 2_000_000 ether;
        vm.prank(deployer);
        address token = factory.deployToken(
            "Capped", "CAP", DEFAULT_DECIMALS, 500_000 ether, cap,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );

        FactoryTokenV2 t = FactoryTokenV2(token);
        assertEq(t.cap(), cap);
        assertEq(t.totalSupply(), 500_000 ether);
    }

    /// @notice Deploy with initialSupply exceeding cap must revert.
    function test_revert_initialExceedsCap() public {
        vm.prank(deployer);
        vm.expectRevert("TokenFactoryV2: CAP_EXCEEDED");
        factory.deployToken(
            "Bad", "BAD", DEFAULT_DECIMALS, 2_000_000 ether, 1_000_000 ether,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
    }

    /// @notice Mint respects the cap.
    function test_mintCapped() public {
        uint256 cap = 1_000_000 ether;
        vm.prank(deployer);
        address token = factory.deployToken(
            "Capped", "CAP", DEFAULT_DECIMALS, 0, cap,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
        FactoryTokenV2 t = FactoryTokenV2(token);

        vm.prank(deployer);
        t.mint(alice, 600_000 ether);
        assertEq(t.totalSupply(), 600_000 ether);

        // Mint up to cap — should succeed
        vm.prank(deployer);
        t.mint(bob, 400_000 ether);
        assertEq(t.totalSupply(), cap);

        // Exceed cap — must revert
        vm.prank(deployer);
        vm.expectRevert();
        t.mint(alice, 1);
    }

    /// @notice Mint fails for non-owner.
    function test_revert_mintNotOwner() public {
        vm.prank(deployer);
        address token = factory.deployToken(
            "Owned", "OWN", DEFAULT_DECIMALS, 100 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
        FactoryTokenV2 t = FactoryTokenV2(token);

        vm.prank(alice);
        vm.expectRevert();
        t.mint(alice, 50 ether);
    }

    /// @notice Transfers work when not paused.
    function test_transfer() public {
        vm.prank(deployer);
        address token = factory.deployToken(
            "Transfer", "XFR", DEFAULT_DECIMALS, 1_000 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
        FactoryTokenV2 t = FactoryTokenV2(token);

        vm.prank(deployer);
        t.transfer(alice, 400 ether);
        assertEq(t.balanceOf(alice), 400 ether);
        assertEq(t.balanceOf(deployer), 600 ether);
    }

    /// @notice Pause stops transfers, unpause restores them.
    function test_pauseUnpause() public {
        vm.prank(deployer);
        address token = factory.deployToken(
            "Pausable", "PAUS", DEFAULT_DECIMALS, 1_000 ether, 0,
            DEFAULT_PERMIT, true // pauseEnabled = true
        );
        FactoryTokenV2 t = FactoryTokenV2(token);

        // Transfer works
        vm.prank(deployer);
        t.transfer(alice, 100 ether);

        // Pause
        vm.prank(deployer);
        t.pause();
        assertTrue(t.paused());

        // Transfer blocked
        vm.prank(alice);
        vm.expectRevert();
        t.transfer(bob, 50 ether);

        // Unpause
        vm.prank(deployer);
        t.unpause();
        assertFalse(t.paused());

        // Transfer works again
        vm.prank(alice);
        t.transfer(bob, 50 ether);
        assertEq(t.balanceOf(bob), 50 ether);
    }

    /// @notice Pause reverts when pauseEnabled is false at deploy time.
    function test_revert_pauseDisabled() public {
        vm.prank(deployer);
        address token = factory.deployToken(
            "NoPause", "NOP", DEFAULT_DECIMALS, 1_000 ether, 0,
            DEFAULT_PERMIT, false // pauseEnabled = false
        );
        FactoryTokenV2 t = FactoryTokenV2(token);

        vm.prank(deployer);
        vm.expectRevert("FactoryTokenV2: PAUSE_DISABLED");
        t.pause();
    }

    /// @notice Only owner can pause.
    function test_revert_pauseNotOwner() public {
        vm.prank(deployer);
        address token = factory.deployToken(
            "Owned", "OWN", DEFAULT_DECIMALS, 100 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
        FactoryTokenV2 t = FactoryTokenV2(token);

        vm.prank(alice);
        vm.expectRevert();
        t.pause();
    }

    /// @notice EIP-2612 permit works for gasless approvals.
    function test_permit() public {
        uint256 ownerKey = 0xA11CE;
        address owner = vm.addr(ownerKey);

        // Deploy token with owner so they have tokens
        vm.prank(owner);
        address tokenAddr = factory.deployToken(
            "Permit", "PRMT", DEFAULT_DECIMALS, 1_000 ether, 0,
            true, DEFAULT_PAUSE // permitEnabled = true
        );
        FactoryTokenV2 t = FactoryTokenV2(tokenAddr);

        // Build a permit
        uint256 value = 100 ether;
        uint256 deadline = block.timestamp + 1 days;

        // Sign permit off-chain
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                value,
                t.nonces(owner),
                deadline
            )
        );

        bytes32 domainSeparator = t.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, digest);

        // Execute permit (anyone can call)
        t.permit(owner, bob, value, deadline, v, r, s);

        // Bob can now transferFrom
        vm.prank(bob);
        t.transferFrom(owner, bob, value);
        assertEq(t.balanceOf(bob), value);
    }

    /// @notice Supply cap works with mint() from owner.
    function test_mintToCap() public {
        vm.prank(deployer);
        address token = factory.deployToken(
            "CappedMint", "CMT", DEFAULT_DECIMALS, 10_000 ether, 10_000 ether,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
        FactoryTokenV2 t = FactoryTokenV2(token);

        // Already at cap — mint should revert
        vm.prank(deployer);
        vm.expectRevert();
        t.mint(deployer, 1);
    }

    /// @notice Zero cap means unlimited.
    function test_unlimitedCap() public {
        vm.prank(deployer);
        address token = factory.deployToken(
            "Unlimited", "UNL", DEFAULT_DECIMALS, 1_000 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
        FactoryTokenV2 t = FactoryTokenV2(token);

        // Mint a large amount — should succeed
        vm.prank(deployer);
        t.mint(alice, 1_000_000_000 ether);
        assertEq(t.totalSupply(), 1_000_001_000 ether);
    }

    /// @notice Factory tracks deployed tokens.
    function test_factoryTracking() public {
        vm.startPrank(deployer);

        address t1 = factory.deployToken(
            "One", "ONE", DEFAULT_DECIMALS, 100 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
        address t2 = factory.deployToken(
            "Two", "TWO", DEFAULT_DECIMALS, 200 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );

        assertEq(factory.tokenCount(deployer), 2);

        address[] memory tokens = factory.tokensOf(deployer);
        assertEq(tokens[0], t1);
        assertEq(tokens[1], t2);

        vm.stopPrank();
    }

    /// @notice Name/symbol validation — empty strings.
    function test_revert_emptyName() public {
        vm.prank(deployer);
        vm.expectRevert("TokenFactoryV2: BAD_NAME");
        factory.deployToken(
            "", "SYM", DEFAULT_DECIMALS, 100 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
    }

    function test_revert_emptySymbol() public {
        vm.prank(deployer);
        vm.expectRevert("TokenFactoryV2: BAD_SYMBOL");
        factory.deployToken(
            "Name", "", DEFAULT_DECIMALS, 100 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
    }

    /// @notice Name at max length (64 chars) succeeds.
    function test_nameMaxLength() public {
        string memory longName = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@";
        assertEq(bytes(longName).length, 64);
        vm.prank(deployer);
        address token = factory.deployToken(
            longName, "MAX", DEFAULT_DECIMALS, 100 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
        assertTrue(token != address(0));
    }

    /// @notice Name exceeding max length (65 chars) reverts.
    function test_revert_nameTooLong() public {
        string memory tooLong = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#";
        assertEq(bytes(tooLong).length, 65);
        vm.prank(deployer);
        vm.expectRevert("TokenFactoryV2: BAD_NAME");
        factory.deployToken(
            tooLong, "LONG", DEFAULT_DECIMALS, 100 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
    }

    /// @notice Symbol at max length (16 chars) succeeds.
    function test_symbolMaxLength() public {
        string memory longSym = "ABCDEFGHIJKLMNOP"; // 16 chars
        assertEq(bytes(longSym).length, 16);
        vm.prank(deployer);
        address token = factory.deployToken(
            "Token", longSym, DEFAULT_DECIMALS, 100 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
        assertTrue(token != address(0));
    }

    /// @notice Symbol exceeding max length (17 chars) reverts.
    function test_revert_symbolTooLong() public {
        string memory tooLong = "ABCDEFGHIJKLMNOPQ"; // 17 chars
        assertEq(bytes(tooLong).length, 17);
        vm.prank(deployer);
        vm.expectRevert("TokenFactoryV2: BAD_SYMBOL");
        factory.deployToken(
            "Token", tooLong, DEFAULT_DECIMALS, 100 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
    }

    /// @notice Deploy with permit disabled.
    function test_deployPermitDisabled() public {
        vm.prank(deployer);
        address token = factory.deployToken(
            "NoPermit", "NOPM", DEFAULT_DECIMALS, 1_000 ether, 0,
            false, DEFAULT_PAUSE
        );
        FactoryTokenV2 t = FactoryTokenV2(token);
        assertEq(t.name(), "NoPermit");
        assertEq(t.symbol(), "NOPM");
        // DOMAIN_SEPARATOR exists even when permit disabled
        // (ERC20Permit is always inherited, just not actively used)
    }

    /// @notice TransferFrom with allowance works.
    function test_transferFrom() public {
        vm.prank(deployer);
        address token = factory.deployToken(
            "Approve", "APR", DEFAULT_DECIMALS, 1_000 ether, 0,
            DEFAULT_PERMIT, DEFAULT_PAUSE
        );
        FactoryTokenV2 t = FactoryTokenV2(token);

        vm.prank(deployer);
        t.approve(alice, 300 ether);

        vm.prank(alice);
        t.transferFrom(deployer, bob, 300 ether);
        assertEq(t.balanceOf(bob), 300 ether);
        assertEq(t.allowance(deployer, alice), 0);
    }
}
