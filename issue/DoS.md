# DoS

## Summary

`_handleTie()` and `_cancelGame()` have DoS vulnerable code

## Finding Description

The contract uses direct ETH transfers with `require`, which make it vulnerable to DoS attack:

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

A malicious player can deploy a contract without `receive()` or `fallback()` functions, causing ETH transfers to that address fail and revert the entire transaction.

## Severity

**Medium** - Permanent fund lockup and game disruption:

- **ETH permanently locked**: No rescue mechanism exists for stuck funds
- **Game corruption**: Games become unresolvable, blocking legitimate gameplay
- **Economic griefing**: Losing players can refuse to pay penalties by blocking transfers
- **Platform instability**: Accumulation of locked games degrades user experience

## Proof of Concept

### Textual PoC

1. Create a contract without `fallback()`/`receive()`
2. Use this contract to join a game &rarr; `game.playerB = attackerContract`
3. In finalizing phrase, `game` contract sending `attackerContract` &rarr; always `revert()`

### Coded PoC

1. Create new [foundry](https://getfoundry.sh/) project
2. Add [Attack contract](../src/DoS.sol) to `src/`
3. Add [Demo](../test/DoS.t.sol) to `test/`
4. Execute

```bash
forge test --mp test/DoS.t.sol
```

5. You should see the following output

```bash
Ran 2 tests for test/DoS.t.sol:JoiningWrongGameTypeTest
[PASS] test_dos_cancelGame() (gas: 405906)
[PASS] test_dos_finishGame() (gas: 472579)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 1.28ms (507.30µs CPU time)

Ran 1 test suite in 11.21ms (1.28ms CPU time): 2 tests passed, 0 failed, 0 skipped (2 total tests)
```

## Recommendation

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
