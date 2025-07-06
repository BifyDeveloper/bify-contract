// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title BifyTokenPayment
 * @dev Handles payments using the Bify token in the marketplace
 */
contract BifyTokenPayment is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    IERC20 public bifyToken;

    uint256 public ethToBifyRate;

    uint256 public platformFeePercentageBify = 25;
    uint256 public constant BASIS_POINTS = 1000;

    address public feeCollector;

    // Events
    event BifyPaymentReceived(
        address indexed payer,
        address indexed receiver,
        uint256 amount,
        bytes32 indexed paymentId
    );

    event FeeCollected(address indexed collector, uint256 amount);

    event RateUpdated(uint256 oldRate, uint256 newRate);

    event FeePercentageUpdated(uint256 oldPercentage, uint256 newPercentage);

    event FeeCollectorUpdated(address oldCollector, address newCollector);

    /**
     * @dev Constructor
     * @param _bifyTokenAddress Address of the Bify token contract
     * @param _initialRate Initial conversion rate from ETH to Bify
     * @param _feeCollector Address that will collect fees
     */
    constructor(
        address _bifyTokenAddress,
        uint256 _initialRate,
        address _feeCollector
    ) {
        require(_feeCollector != address(0), "Invalid fee collector address");
        require(_initialRate > 0, "Rate must be greater than 0");

        if (_bifyTokenAddress != address(0)) {
            bifyToken = IERC20(_bifyTokenAddress);
        }
        ethToBifyRate = _initialRate;
        feeCollector = _feeCollector;
    }

    /**
     * @dev Processes a payment in Bify tokens
     * @param _from Address sending the payment
     * @param _to Address receiving the payment
     * @param _amount Amount in Bify tokens
     * @param _paymentId Unique identifier for the payment (e.g., listing ID or auction ID)
     * @return success Whether the payment was successful
     */
    function processPayment(
        address _from,
        address _to,
        uint256 _amount,
        bytes32 _paymentId
    ) external nonReentrant returns (bool success) {
        require(address(bifyToken) != address(0), "Token not configured");
        require(_from != address(0), "Invalid sender");
        require(_to != address(0), "Invalid receiver");
        require(_amount > 0, "Amount must be greater than 0");

        uint256 feeAmount = _amount.mul(platformFeePercentageBify).div(
            BASIS_POINTS
        );
        uint256 receiverAmount = _amount.sub(feeAmount);

        require(
            bifyToken.transferFrom(_from, address(this), _amount),
            "Token transfer failed"
        );

        require(
            bifyToken.transfer(_to, receiverAmount),
            "Receiver transfer failed"
        );

        if (feeAmount > 0) {
            require(
                bifyToken.transfer(feeCollector, feeAmount),
                "Fee transfer failed"
            );

            emit FeeCollected(feeCollector, feeAmount);
        }

        emit BifyPaymentReceived(_from, _to, _amount, _paymentId);

        return true;
    }

    /**
     * @dev Convert ETH amount to equivalent Bify amount
     * @param _ethAmount Amount in ETH (in wei)
     * @return bifyAmount Equivalent amount in Bify tokens
     */
    function ethToBify(
        uint256 _ethAmount
    ) public view returns (uint256 bifyAmount) {
        return _ethAmount.mul(ethToBifyRate).div(1e18);
    }

    /**
     * @dev Convert Bify amount to equivalent ETH amount
     * @param _bifyAmount Amount in Bify tokens
     * @return ethAmount Equivalent amount in ETH (in wei)
     */
    function bifyToEth(
        uint256 _bifyAmount
    ) public view returns (uint256 ethAmount) {
        return _bifyAmount.mul(1e18).div(ethToBifyRate);
    }

    /**
     * @dev Update the ETH to Bify conversion rate
     * @param _newRate New conversion rate
     */
    function updateRate(uint256 _newRate) external onlyOwner {
        require(_newRate > 0, "Rate must be greater than 0");

        uint256 oldRate = ethToBifyRate;
        ethToBifyRate = _newRate;

        emit RateUpdated(oldRate, _newRate);
    }

    /**
     * @dev Update the platform fee percentage for Bify payments
     * @param _newPercentage New fee percentage in basis points
     */
    function updateFeePercentage(uint256 _newPercentage) external onlyOwner {
        require(_newPercentage <= 50, "Fee cannot exceed 5%");

        uint256 oldPercentage = platformFeePercentageBify;
        platformFeePercentageBify = _newPercentage;

        emit FeePercentageUpdated(oldPercentage, _newPercentage);
    }

    /**
     * @dev Update the fee collector address
     * @param _newCollector New fee collector address
     */
    function updateFeeCollector(address _newCollector) external onlyOwner {
        require(_newCollector != address(0), "Invalid fee collector address");

        address oldCollector = feeCollector;
        feeCollector = _newCollector;

        emit FeeCollectorUpdated(oldCollector, _newCollector);
    }

    /**
     * @dev Emergency withdrawal of any stuck tokens
     * @param _token Address of the token to withdraw
     */
    function emergencyWithdraw(address _token) external onlyOwner {
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");

        token.transfer(owner(), balance);
    }
}
