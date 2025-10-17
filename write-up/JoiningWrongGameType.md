# Joining wrong game type

## Summary

Player B can join token game without collateral via `joinGameWithEth`.

## Finding Description

There're 2 distinct game type: and token game with separate workflow:

- **ETH game**: `createGameWithEth` &rarr; `joinGameWithEth` &rarr; ...
- **Token game**: `createGameWithToken`&rarr; `joinGameWithToken` &rarr; ...

All ETH game must have `game.bet >= minBet`, so the contract use `game.bet == 0` to distinguish token game from ETH game in order to save a bool state.

```solidity
function joinGameWithEth(uint256 _gameId) external payable {
    Game storage game = games[_gameId];

    require(game.state == GameState.Created, "Game not open to join");
    require(game.playerA != msg.sender, "Cannot join your own game");
    require(block.timestamp <= game.joinDeadline, "Join deadline passed");
    require(msg.value == game.bet, "Bet amount must match creator's bet");

    game.playerB = msg.sender;
    emit PlayerJoined(_gameId, msg.sender);
}
```

However, `joinGameWithEth` lacks validation to prevent joining token games, which allow an unexpected workflow: `createGameWithToken` → `joinGameWithEth` &rarr; ...

## Severity

**High** - Unlimited token inflation:

- **Economic exploit**: Attackers can mint unlimited `RPSW` with minimal investment.
- **Token devaluation**: Mass minting leads to RPSW price collapse and ecosystem damage.

## Proof of Concept

### Textual PoC

1. `createGameWithToken(...)`

- `attacker1` -1 `RPSW`
- New game's created with `game.bet = 0`
- Get `gameId`

2. `joinGameWithEth(gameId)` &rarr; `attacker2` join the game without collateral
3. `cancelGame(gameId)`

- `attacker1` +1 `RPSW` (refund)
- `attacker2` +1 `RPSW` (earn)

### Coded PoC

1. Create new [foundry](https://getfoundry.sh/) project
2. Add [Demo](../test/JoinningWrongGameType.t.sol) to `test/`
3. Execute

```bash
forge tests --mt test_joiningWrongGameType
```

5. You should see the following output

```bash
[⠊] Compiling...
[⠢] Compiling 2 files with Solc 0.8.20
[⠆] Solc 0.8.20 finished in 14.21s
Compiler run successful!

Ran 1 test for test/1.t.sol:JoiningWrongGameTypeTest
[PASS] test_joiningWrongGameType() (gas: 20754899)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 10.30ms (9.05ms CPU time)

Ran 1 test suite in 14.71ms (10.30ms CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```

## Recommendation

Add a game type validation to prevent unexpected joining.

```solidity
function joinGameWithEth(uint256 _gameId) external payable {
    Game storage game = games[_gameId];

    require(game.bet > minBet, "Must join game with token");
    //...
}
```
