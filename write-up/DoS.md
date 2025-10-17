# DoS

## Summary

`_handleTie()` and `_cancelGame()` are vulnerable to DoS attacks. A malicious player can deploy a contract that reverts on ETH transfer, permanently locking all game funds.

## Description

### Normal Behavior

- Players receive refunds when an ETH game ends in a tie
- Players receive refunds when both fail to reveal moves (timeout cancellation)

### Issue

```solidity
function _handleTie(uint256 _gameId) internal {
    //...
    if (game.bet > 0) {
        //...
        (bool successA,) = game.playerA.call{value: refundPerPlayer}("");
        (bool successB,) = game.playerB.call{value: refundPerPlayer}("");
        require(successA && successB, "Transfer failed");
    }
    //...
}
```

```solidity
function _cancelGame(uint256 _gameId) internal {
    //...
    if (game.bet > 0) {
        (bool successA,) = game.playerA.call{value: game.bet}("");
        require(successA, "Transfer to player A failed");

        if (game.playerB != address(0)) {
            (bool successB,) = game.playerB.call{value: game.bet}("");
            require(successB, "Transfer to player B failed");
        }
    }
    //...
}
```

Both functions use direct ETH transfers with `require`, causing the entire transaction to revert if any transfer fails. A malicious player can revert their receive function to block all refunds.

## Risk

### Impact

**High**

- All game funds permanently locked in contract
- No recovery mechanism exists
- Honest players lose their collateral

### Likelihood

**Medium**

- Easy to execute (simple reverting contract)
- Works in tie scenarios and timeout cancellations
- Attacker also loses their bet, reducing financial incentive but enables griefing

## Proof of Concept

### Textual PoC

1. Player create a game with eth
2. Attacker join the game by his malicious contract (fallback consume all gas/revert)
3. PLayer and attacker play until the game tie or both forget to reveal move
   _Note: attacker can commit same move and then reveal same salt with player to ensure the game tie_
4. When `_handleTie()` or `_cancelGame()` tries to refund, the malicious contract reverts

### Coded PoC

[DoS.t.sol](../test/DoS.t.sol)

## Recommended Mitigation

1. Implement [Withdrawal pattern](https://blog.b9lab.com/the-solidity-withdrawal-pattern-1602cb32f1a5)

```solidity
contract RockPaperScissors {
    mapping(address => uint256) balances;

    function withdraw() public {
        uint256 balance = balances[msg.sender];
        balances[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: balance}();
        require(success);
    }
    //...
}
```

```solidity
function _handleTie(uint256 _gameId) internal {
    //...
    if (game.bet > 0) {
        //...
        balances[playerA] += refundPerPlayer;
        balances[playerB] += refundPerPlayer;
    }
    //...
}
```

```solidity
function _cancelGame(uint256 _gameId) internal {
    //...
    if (game.bet > 0) {
        balances[playerA] += game.bet;

        if (game.playerB != address(0)) {
            (bool successB,) = game.playerB.call{value: game.bet}("");
            balances[playerA] += refundPerPlayer;
        }
    }
    //...
}
```

2. Add emergency rescue meachanism for future dilemma resolving

```solidity
function rescue(address payable receiver, uint256 amount) {
    require(msg.sender == adminAddress, "Only admin can withdraw fees");
    (bool success, ) = receiver.call{value: amount}();
    require(success);
}
```
