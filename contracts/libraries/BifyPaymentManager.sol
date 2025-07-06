// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BifyPaymentManager
 * @dev Library for handling payments in BifyLaunchpad
 */
library BifyPaymentManager {
    /**
     * @notice Process payment for collection creation, with ETH or ERC20 token
     * @param useBifyPayment Whether to use the Bify token for payment
     * @param allowBifyPayment Whether Bify token payment is enabled
     * @param bifyFee Fee amount in Bify tokens
     * @param bifyToken Bify token contract
     * @param payer Address making the payment
     * @param feeRecipient Address receiving the fee
     * @param platformFee Fee amount in ETH
     * @param msgValue Sent ETH value
     */
    function processPayment(
        bool useBifyPayment,
        bool allowBifyPayment,
        uint256 bifyFee,
        IERC20 bifyToken,
        address payer,
        address feeRecipient,
        uint256 platformFee,
        uint256 msgValue
    ) external {
        if (useBifyPayment) {
            require(allowBifyPayment, "Bify payment not enabled");
            require(bifyFee > 0, "Bify fee not set");
            require(
                bifyToken.transferFrom(payer, feeRecipient, bifyFee),
                "Bify fee transfer failed"
            );
        } else {
            require(msgValue >= platformFee, "Insufficient fee");

            (bool success, ) = feeRecipient.call{value: platformFee}("");
            require(success, "Fee transfer failed");

            uint256 refund = msgValue - platformFee;
            if (refund > 0) {
                (bool refundSuccess, ) = payer.call{value: refund}("");
                require(refundSuccess, "Refund transfer failed");
            }
        }
    }

    /**
     * @notice Emergency withdrawal of ETH
     * @param recipient Address to receive the withdrawn ETH
     * @return success Whether the withdrawal was successful
     * @return balance Amount of ETH withdrawn
     */
    function emergencyWithdrawETH(
        address recipient
    ) external returns (bool success, uint256 balance) {
        balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        (success, ) = recipient.call{value: balance}("");
        return (success, balance);
    }

    /**
     * @notice Emergency withdrawal of ERC20 tokens
     * @param tokenAddress Address of the token contract
     * @param recipient Address to receive the withdrawn tokens
     * @return amount Amount of tokens withdrawn
     */
    function emergencyWithdrawERC20(
        address tokenAddress,
        address recipient
    ) external returns (uint256 amount) {
        IERC20 token = IERC20(tokenAddress);
        amount = token.balanceOf(address(this));
        require(amount > 0, "No tokens to withdraw");

        token.transfer(recipient, amount);
        return amount;
    }
}
