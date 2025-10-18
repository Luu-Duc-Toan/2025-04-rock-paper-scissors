// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/RockPaperScissors.sol";
import "../src/WinningToken.sol";

contract RockPaperScissorsTest is Test {
    // Contracts
    RockPaperScissors public game;
    WinningToken public token;

    // Test accounts
    address public admin;
    address public playerA;
    address public playerB;

    // Test constants
    uint256 constant BET_AMOUNT = 0.1 ether;
    uint256 constant TIMEOUT = 10 minutes;
    uint256 constant TOTAL_TURNS = 3; // Must be odd

    // Game ID for tests
    uint256 public gameId;

    // Setup before each test
    function setUp() public {
        // Set up addresses
        admin = address(this);
        playerA = makeAddr("playerA");
        playerB = makeAddr("playerB");

        // Fund the players
        vm.deal(playerA, 10 ether);
        vm.deal(playerB, 10 ether);

        // Deploy contracts
        game = new RockPaperScissors();
        token = WinningToken(game.winningToken());

        // Mint some tokens for players for token tests
        vm.prank(address(game));
        token.mint(playerA, 10);

        vm.prank(address(game));
        token.mint(playerB, 10);
    }

    function createGame(address _creator) public returns (uint256) {
        vm.prank(_creator);
        uint256 _gameId = game.createGameWithEth{value: BET_AMOUNT}(
            TOTAL_TURNS,
            TIMEOUT
        );
        return _gameId;
    }

    function joinGame(address _joiner, uint256 _gameId) public {
        vm.prank(_joiner);
        game.joinGameWithEth{value: BET_AMOUNT}(_gameId);
    }

    function commitMove(
        address _player,
        uint256 _gameId,
        uint8 _move
    ) public returns (bytes32) {
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, _player));
        vm.prank(_player);
        game.commitMove(_gameId, keccak256(abi.encodePacked(_move, salt)));
        return salt;
    }

    function playTurn(uint256 _gameId, address _winner, address _loser) public {
        bytes32 winnerSalt = commitMove(
            _winner,
            _gameId,
            uint8(RockPaperScissors.Move.Rock)
        );
        bytes32 loserSalt = commitMove(
            _loser,
            _gameId,
            uint8(RockPaperScissors.Move.Scissors)
        );

        vm.prank(_winner);
        game.revealMove(
            _gameId,
            uint8(RockPaperScissors.Move.Rock),
            winnerSalt
        );
        vm.prank(_loser);
        game.revealMove(
            _gameId,
            uint8(RockPaperScissors.Move.Scissors),
            loserSalt
        );
    }

    function testTimeoutRevealInCommitPhase() public {
        uint256 gameId_ = createGame(playerA);
        joinGame(playerB, gameId_);

        playTurn(gameId_, playerA, playerB); // Turn 1: A wins
        playTurn(gameId_, playerA, playerB); // Turn 2: A wins
        // Turn 3
        commitMove(playerA, gameId_, uint8(RockPaperScissors.Move.Scissors));

        uint256 turn2RevealTime = block.timestamp + TIMEOUT;
        vm.warp(turn2RevealTime + 1);
        vm.prank(playerB);
        game.timeoutReveal(gameId_);
    }
}
