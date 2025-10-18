# Call `timeoutReveal()` In Commit Phase

## Summary

After turn 1, `revealDeadline` is not updated in subsequent turns. A losing player can skip committing and call `timeoutReveal()` to force the game to end in a tie.

## Description

### Normal Behavior

- Each turn has a `revealDeadline` in reveal phase that if no player reveals, the game ends in a tie
- Reveal phase functions shouldn't be callable in commit phase

### Issue

`revealDeadline` is updated only when both players commit in commit phase:

```solidity
function commitMove(uint256 _gameId, bytes32 _commitHash) external {
    //...
    // If both players have committed, set the reveal deadline
    if (game.commitA != bytes32(0) && game.commitB != bytes32(0)) {
        game.revealDeadline = block.timestamp + game.timeoutInterval;
    }
}
```

Because **commit phase and reveal phase use the same state** `GameState.Committed`, an attacker can call `timeoutReveal()` during commit phase:

```solidity
function timeoutReveal(uint256 _gameId) external {
    //...
    require(game.state == GameState.Committed, "Game not in reveal phase");
    //...
}
```

The attacker can pass the time check using the previous turn's `revealDeadline`:

```solidity
function timeoutReveal(uint256 _gameId) external {
    //...
    require(
        block.timestamp > game.revealDeadline,
        "Reveal phase not timed out yet"
    );
    //...
}
```

In commit phase, the legitimate player will not reveal their commit (or they'll absolutely lose), so the game ends in a tie:

```solidity
function timeoutReveal(uint256 _gameId) external {
    //...
    bool playerARevealed = game.moveA != Move.None;
    bool playerBRevealed = game.moveB != Move.None;
    //...
    else if (!playerARevealed && !playerBRevealed) {
        _cancelGame(_gameId); // Neither player revealed, cancel and refund
    }
}
```

## Risk

### Impact

**High**

- Winning player is denied their rightful reward
- Losing player can exploit this to avoid loss and reclaim their collateral

### Likelihood

**High**

- All games become exploitable after turn 1 with minimal wait time
- Losing player has strong economic incentive to exploit this vulnerability

## Proof of Concept

### Textual PoC

1. PlayerA creates a game with 3 turns
2. PlayerB joins the game
3. PlayerA wins turn 1 and turn 2, so playerB knows they cannot win
4. PlayerB skips committing in turn 3 commit phase
5. Since `revealDeadline` from turn 2 was never updated, playerB waits for the deadline to pass and calls `timeoutReveal()`
6. Because neither player revealed, the game is cancelled by `_cancelGame()` and both players get refunds

### Coded PoC

[TimeoutRevealInCommitPhrase.t.sol](../test/TimeoutRevealInCommitPhrase.t.sol)

## Recommended Mitigation

Distinguish commit phase and reveal phase using separate game states:

```diff
function commitMove(uint256 _gameId, bytes32 _commitHash) external {
    //...
    // If both players have committed, set the reveal deadline
    if (game.commitA != bytes32(0) && game.commitB != bytes32(0)) {
        game.revealDeadline = block.timestamp + game.timeoutInterval;
+       game.state = GameState.Revealed;
    }
}

function timeoutReveal(uint256 _gameId) external {
    Game storage game = games[_gameId];

    require(msg.sender == game.playerA || msg.sender == game.playerB, "Not a player");
-   require(game.state == GameState.Committed, "Game not in reveal phase");
+   require(game.state == GameState.Revealed, "Game not in reveal phase")
    require(
        block.timestamp > game.revealDeadline,
        "Reveal phase not timed out yet"
    );
    //..
    }
}
```
