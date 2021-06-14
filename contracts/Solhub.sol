// SPDX-License-Identifier: MIT
pragma solidity 0.5.7;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

/// @title Solhub
/// @notice ERC-20 implementation of SHBT token
contract Solhub is ERC20, ERC20Detailed, Ownable {
    event LogEtherTransferred(address indexed receiver, uint256 eth);

    /**
     * @dev Sets the values for {name = SolhubCoin}, {totalSupply = 1 Billion}, {decimals = 18} and {symbol = SHBT}.
     *
     * All three of these values (name, symbol, decimals) are immutable: they can only be set once during
     * construction.
     */
    constructor(uint256 initialSupply, uint8 _decimals)
        public
        ERC20Detailed("SolhubCoin", "SHBT", _decimals)
    {
        super._mint(msg.sender, initialSupply); // Since Total supply 1 Billion
    }

    /**
     * @dev Contract might receive/hold ETH as part of the maintenance process.
     * The receive function is executed on a call to the contract with empty calldata.
     */
    // solhint-disable-next-line no-empty-blocks
    function() external payable {}

    /**
     * @dev Creates `amount` tokens from `account`, increasing the
     * total supply.
     *
     * Requirements:
     * - invocation can be done, only by the contract owner.
     */
    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     */
    function burn(uint256 amount) public {
        require(
            balanceOf(msg.sender) >= amount,
            "Cannot burn more than balance"
        );
        _burn(msg.sender, amount);
    }

    /**
     * @dev To transfer all BNBs stored in the contract to the caller
     *
     * Requirements:
     * - invocation can be done, only by the contract owner.
     */
    function withdrawAll() public payable onlyOwner {
        if (msg.sender.send(address(this).balance)) {
            emit LogEtherTransferred(msg.sender, address(this).balance);
        } else {
            revert("Withdraw Eth failed");
        }
    }
}
