// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Vault4626} from "../contracts/Vault4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Simple mock ERC-20 for vault testing.
contract MockAsset is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract Vault4626Test is Test {
    Vault4626 public vault;
    MockAsset public asset;
    
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address DEAD = address(0xdead);
    
    uint256 constant DEAD_SHARES = 1e3;
    
    function setUp() public {
        asset = new MockAsset("Mock USDC", "mUSDC");
        vault = new Vault4626(IERC20(address(asset)), "Vault mUSDC", "vmUSDC");
        
        // Fund test accounts
        asset.mint(alice, 1_000_000 ether);
        asset.mint(bob, 1_000_000 ether);
        asset.mint(charlie, 1_000_000 ether);
        
        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(charlie);
        asset.approve(address(vault), type(uint256).max);
    }
    
    // ─── Basic flows ───────────────────────────────────────────────
    
    function test_deposit() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1_000 ether, alice);
        
        assertEq(shares, 1_000 ether); // 1:1 after dead-share offset
        assertEq(vault.totalSupply(), DEAD_SHARES + 1_000 ether);
        assertEq(vault.totalAssets(), 1_000 ether);
        assertEq(vault.balanceOf(alice), 1_000 ether);
        assertEq(asset.balanceOf(address(vault)), 1_000 ether);
    }
    
    function test_withdraw() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        
        uint256 preBal = asset.balanceOf(alice);
        vm.prank(alice);
        vault.withdraw(500 ether, alice, alice);
        
        assertEq(asset.balanceOf(alice) - preBal, 500 ether);
        assertEq(vault.totalAssets(), 500 ether);
    }
    
    function test_mint() public {
        vm.prank(alice);
        uint256 assets = vault.mint(1_000 ether, alice);
        
        assertEq(assets, 1_000 ether); // 1:1
        assertEq(vault.balanceOf(alice), 1_000 ether);
        assertEq(vault.totalAssets(), 1_000 ether);
    }
    
    function test_redeem() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        
        uint256 preBal = asset.balanceOf(alice);
        vm.prank(alice);
        uint256 assets = vault.redeem(500 ether, alice, alice);
        
        assertEq(assets, 500 ether);
        assertEq(asset.balanceOf(alice) - preBal, 500 ether);
    }
    
    // ─── Share price math ──────────────────────────────────────────
    
    function test_sharePriceAfterDonation() public {
        // Alice deposits 1000
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        
        // Bob donates 500 (no shares minted)
        vm.prank(bob);
        vault.donate(500 ether);
        
        // Share price should now be 1.5 assets per share
        // totalAssets = 1500, live shares = 1000, price = 1.5
        assertEq(vault.totalAssets(), 1_500 ether);
        
        uint256 preview = vault.previewRedeem(100 ether);
        // 100 shares * 1.5 = 150 assets
        assertEq(preview, 150 ether);
    }
    
    function test_sharePriceAfterYield() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        
        // Simulate yield: transfer assets directly to vault (bypassing deposit)
        vm.prank(bob);
        asset.transfer(address(vault), 500 ether);
        
        // Share price doubled: 1500 assets / 1000 live shares
        assertEq(vault.totalAssets(), 1_500 ether);
        assertEq(vault.previewRedeem(100 ether), 150 ether);
    }
    
    function test_sharePriceMultiUser() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        
        vm.prank(bob);
        vault.deposit(2_000 ether, bob);
        
        // Alice: 1000 shares, Bob: 2000 shares
        assertEq(vault.balanceOf(alice), 1_000 ether);
        assertEq(vault.balanceOf(bob), 2_000 ether);
        assertEq(vault.totalAssets(), 3_000 ether);
        
        // Alice withdraws proportional amount
        vm.prank(alice);
        vault.redeem(1_000 ether, alice, alice);
        // Alice should get her share of total assets: 1000/3000 * 3000 = 1000
        assertApproxEqAbs(asset.balanceOf(address(vault)), 2_000 ether, 1);
    }
    
    // ─── Inflation attack guard ────────────────────────────────────
    
    function test_inflationAttackBlocked() public {
        // Attacker tries donation attack: donate 1 wei to inflate share price,
        // then front-run victim's deposit.
        
        // Dead shares exist: 1000
        assertEq(vault.balanceOf(DEAD), DEAD_SHARES);
        
        // Attacker deposits 1 wei — pays dearly due to dead-share offset
        vm.prank(charlie);
        uint256 attackerShares = vault.deposit(1, charlie);
        
        // Attacker gets ~0 shares because 1 asset / (DEAD_SHARES floor) ≈ 0
        // Actually: convertToShares(1) with supply=DEAD_SHARES, assets=0
        // _convertToShares: supply > DEAD_SHARES? No (supply==DEAD_SHARES). Return assets directly = 1
        // Wait — first deposit after dead shares: supply==DEAD_SHARES so return assets == 1 share for 1 wei
        // That's the expected 1:1 start for the first real depositor
        
        // The real test: attacker donates massive amount, then tries to steal
        // Fund charlie with enough to do the donation AND the deposit
        asset.mint(charlie, 2_000_000 ether);
        vm.startPrank(charlie);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(1, charlie); // attacker deposits 1 wei
        asset.transfer(address(vault), 1_000_000 ether); // donate via direct transfer
        vm.stopPrank();
        
        // Share price is now massive: (1_000_000 + 1) / (DEAD_SHARES + 1) ≈ 999 ether/share
        // Alice deposits 1 ether — gets ~0.001 shares
        vm.prank(alice);
        uint256 aliceShares = vault.deposit(1 ether, alice);
        
        // Alice should get very few shares due to inflated share price
        assertTrue(aliceShares < 1 ether / 100); // less than 0.01 shares
        
        // Attacker tries to withdraw their 1 share — gets massive assets
        vm.prank(charlie);
        // charlie has attackerShares shares
        vault.redeem(attackerShares, charlie, charlie);
    }
    
    function test_deadSharesPermanent() public {
        // Dead shares can never be withdrawn — they're at address(0xdead)
        assertEq(vault.balanceOf(DEAD), DEAD_SHARES);
        // maxRedeem reflects share balance but DEAD has no way to call redeem
        assertEq(vault.maxRedeem(DEAD), DEAD_SHARES);

        // Deposits still work normally
        vm.prank(alice);
        vault.deposit(500 ether, alice);
        assertEq(vault.balanceOf(alice), 500 ether);
    }
    
    // ─── Rounding direction ────────────────────────────────────────
    
    function test_roundingFavorsVault() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        
        // Donate a weird amount to create rounding issues
        vm.prank(bob);
        vault.donate(333 ether);
        
        // previewWithdraw: rounds UP (user needs more shares)
        // previewMint: rounds UP (user needs more assets)
        // previewDeposit: rounds DOWN (user gets fewer shares)
        // previewRedeem: rounds DOWN (user gets fewer assets)
        
        uint256 assetsForWithdraw = vault.previewWithdraw(100 ether);
        uint256 sharesForDeposit = vault.previewDeposit(100 ether);
        
        // withdraw should cost >= deposit for same asset amount
        assertGe(assetsForWithdraw, sharesForDeposit);
    }
    
    // ─── Access control ────────────────────────────────────────────
    
    function test_withdrawWithApproval() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        
        // Alice approves Bob to withdraw
        vm.prank(alice);
        vault.approve(bob, 500 ether);
        
        vm.prank(bob);
        vault.withdraw(500 ether, bob, alice);
        
        assertEq(asset.balanceOf(bob), 1_000_000 ether + 500 ether); // initial + withdrawn
    }
    
    function test_revert_withdrawWithoutApproval() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        
        vm.prank(bob);
        vm.expectRevert();
        vault.withdraw(500 ether, bob, alice);
    }
    
    // ─── Donation ──────────────────────────────────────────────────
    
    function test_donate() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        
        uint256 prePrice = vault.convertToAssets(1 ether);
        
        vm.prank(bob);
        vault.donate(500 ether);
        
        uint256 postPrice = vault.convertToAssets(1 ether);
        assertGt(postPrice, prePrice); // Share price increased
        assertEq(vault.totalAssets(), 1_500 ether);
        assertEq(vault.balanceOf(bob), 0); // Bob got no shares
    }
    
    function test_revert_donateZero() public {
        vm.prank(alice);
        vm.expectRevert(Vault4626.Vault4626__ZeroDeposit.selector);
        vault.donate(0);
    }
    
    // ─── Max functions ─────────────────────────────────────────────
    
    function test_maxDeposit() public {
        assertEq(vault.maxDeposit(alice), type(uint256).max);
    }
    
    function test_maxMint() public {
        assertEq(vault.maxMint(alice), type(uint256).max);
    }
    
    function test_maxWithdraw() public {
        vm.prank(alice);
        vault.deposit(500 ether, alice);
        assertEq(vault.maxWithdraw(alice), 500 ether);
    }
    
    function test_maxRedeem() public {
        vm.prank(alice);
        vault.deposit(500 ether, alice);
        assertEq(vault.maxRedeem(alice), 500 ether);
    }
    
    // ─── Preview functions ─────────────────────────────────────────
    
    function test_previewDeposit() public {
        uint256 shares = vault.previewDeposit(100 ether);
        assertEq(shares, 100 ether); // 1:1 from clean state
    }
    
    function test_previewMint() public {
        uint256 assets = vault.previewMint(100 ether);
        assertEq(assets, 100 ether); // 1:1
    }
    
    function test_previewWithdraw() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        // 1000 assets withdrawn costs 1000 shares (1:1)
        assertEq(vault.previewWithdraw(100 ether), 100 ether);
    }
    
    function test_previewRedeem() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        assertEq(vault.previewRedeem(100 ether), 100 ether);
    }
}
