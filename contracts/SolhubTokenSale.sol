// SPDX-License-Identifier: MIT
pragma solidity 0.5.7;

import "@chainlink/contracts/src/v0.5/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/roles/WhitelistedRole.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";

/// @title SolhubTokenSale
/// @notice Parent Sale Contract for Solhub Tokens
contract SolhubTokenSale is WhitelistedRole, ReentrancyGuard, TimedCrowdsale {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    /// @dev allowance is # of SHBT each participant can withdraw.
    /// @param currentAllowance this allowance is in 4 stages tracked by currentAllowance.
    /// @param shareWithdrawn tracks the amount of SHBT already withdrawn.
    /// @param dollarUnitsPayed 1 dollar = 1,000,000 dollar units.
    /// This tracks dollar units payed by user to this contract.
    struct UserSHBTInfo {
        uint256 dollarUnitsPayed;
        uint256 allocatedSHBT;
        uint256 currentAllowance;
        uint256 shareWithdrawn;
    }

    // Below storage variables will be set from the derived contracts via constructor
    //solhint-disable-next-line var-name-mixedcase
    uint256 public HARD_CAP;
    uint256 public minimumContributionInUSDT;
    uint256 public maximumContributionInUSDT;
    //solhint-disable-next-line var-name-mixedcase
    uint256 public SHBT_PRICE_PER_USDT;
    //solhint-disable-next-line var-name-mixedcase
    IERC20 public USDT_TOKEN;

    mapping(address => UserSHBTInfo) public allocatedSHBTRegistry;
    uint256 public netSoldSHBTs;

    /// Variables whose instance fetch prices of USDT, ETH from Chainlink oracles
    AggregatorV3Interface internal chainlinkPriceFeedETH;
    AggregatorV3Interface internal chainlinkPriceFeedUSDT;

    /// Events
    event LogEtherReceived(address indexed sender, uint256 value);
    event LogSHBTBoughtUsingETH(
        address indexed buyer,
        uint256 incomingWei,
        uint256 allocation
    );
    event LogSHBTBoughtUsingUSDT(
        address indexed buyer,
        uint256 incomingUsdtUnits,
        uint256 allocation
    );
    event LogChainlinkETHPriceFeedChange(
        address indexed newChainlinkETHPriceFeed
    );
    event LogChainlinkUSDTPriceFeedChange(
        address indexed newChainlinkUSDTPriceFeed
    );
    event LogUSDTInstanceChanged(address indexed newUsdtContract);
    event LogMaxMinContributionChanged(
        uint256 newMinContribuitionInUSDT,
        uint256 newMaxContribuitionInUSDT
    );

    /// @dev ensuring SHBT allocations in don't exceed HARD_CAP
    modifier tokensRemaining() {
        require(netSoldSHBTs <= HARD_CAP, "SolhubTokenSale: All tokens sold");
        _;
    }

    /**
     * @param _openingTime sale starting time.
     * @param _closingTime sale closing time.
     * @param _chainlinkETHPriceFeed address of the ETH price feed.
     * @param _chainlinkUSDTPriceFeed address of the USDT price feed.
     * @param _usdtContract address of the USDT ERC20 contract.
     * @param _token SHBT token address
     * @param _wallet where ETH end USDT will be transferred.
     */
    constructor(
        uint256 _openingTime,
        uint256 _closingTime,
        uint256 _shbtPricePerUSDT,
        address _chainlinkETHPriceFeed,
        address _chainlinkUSDTPriceFeed,
        address _usdtContract,
        IERC20 _token,
        address payable _wallet
    )
        public
        WhitelistedRole()
        TimedCrowdsale(_openingTime, _closingTime)
        Crowdsale(1, _wallet, _token)
    {
        require(_shbtPricePerUSDT > 0, "SolhubTokenSale: SHBT price <= 0");
        SHBT_PRICE_PER_USDT = _shbtPricePerUSDT;
        chainlinkPriceFeedETH = AggregatorV3Interface(_chainlinkETHPriceFeed);
        chainlinkPriceFeedUSDT = AggregatorV3Interface(_chainlinkUSDTPriceFeed);
        USDT_TOKEN = IERC20(_usdtContract);
    }

    /**
     * @dev The fallback function is executed on a call to the contract if
     * none of the other functions match the given function signature.
     */
    function() external payable {
        emit LogEtherReceived(_msgSender(), msg.value);
    }

    /**
     * @dev Update ETH priceFeed instance
     */
    function setETHPriceFeed(address _newChainlinkETHPriceFeed)
        external
        onlyWhitelistAdmin
    {
        chainlinkPriceFeedETH = AggregatorV3Interface(
            _newChainlinkETHPriceFeed
        );
        emit LogChainlinkETHPriceFeedChange(_newChainlinkETHPriceFeed);
    }

    /**
     * @dev Update USDT priceFeed instance
     */
    function setUSDTPriceFeed(address _newUSDTPriceFeed)
        external
        onlyWhitelistAdmin
    {
        chainlinkPriceFeedUSDT = AggregatorV3Interface(_newUSDTPriceFeed);
        emit LogChainlinkUSDTPriceFeedChange(_newUSDTPriceFeed);
    }

    /**
     * @dev Update USDT instance
     */
    function setUSDTInstance(address _newUSDTContract)
        external
        onlyWhitelistAdmin
    {
        USDT_TOKEN = IERC20(_newUSDTContract);
        emit LogUSDTInstanceChanged(_newUSDTContract);
    }

    /**
     * @dev Allows users to allocate SHBTs for themselves using ETH
     *
     * It fetches current price of ETH, multiples that by incoming ETH to calc total incoming dollar units, then
     * allocates appropriate amount of SHBT to user based on current rate, stage
     *
     * Requirements:
     * - only KYC/AML whitelisted users can call this, while the sale is open and allocation hard cap is not reached
     * - can be called only when sale is open
     * - will only succeed if tokens are remaining
     */
    function buySHBTUsingETH()
        external
        payable
        onlyWhileOpen
        tokensRemaining
        nonReentrant
    {
        uint256 allocation;
        uint256 ethPrice = uint256(fetchETHPrice());
        uint256 dollarUnits = ethPrice.mul(msg.value).div(1e18);
        allocation = allocateSHBT(dollarUnits);
        _forwardFunds(); // Since Crowdsale has _wallet storage variable
        emit LogSHBTBoughtUsingETH(_msgSender(), msg.value, allocation);
    }

    /**
     * @dev Allows users to allocate SHBTs for themselves using USDT
     */
    function buySHBTUsingUSDT(uint256 incomingUsdt)
        external
        onlyWhileOpen
        tokensRemaining
        nonReentrant
    {
        uint256 allocation;
        uint256 usdtPrice = uint256(fetchUSDTPrice());
        uint256 dollarUnits = usdtPrice.mul(incomingUsdt).div(1e6);
        allocation = allocateSHBT(dollarUnits);
        USDT_TOKEN.safeTransferFrom(_msgSender(), wallet(), incomingUsdt);
        emit LogSHBTBoughtUsingUSDT(_msgSender(), incomingUsdt, allocation);
    }

    /**
     * @dev To set admin
     *
     * Requirements
     *
     * - Can only be invoked by white listed admins
     */
    function setAdmin(address _admin) public onlyWhitelistAdmin {
        // Add new admin for whitelisting, and remove msgSender as admin
        addWhitelistAdmin(_admin);
        renounceWhitelistAdmin();
    }

    /**
     * @dev To update $(USDT) Contribution limits
     *
     * Requirements
     *
     * - Can only be invoked by white listed admins
     */
    function setUSDTContributionLimits(uint256 _newMin, uint256 _newMax)
        public
        onlyWhitelistAdmin
    {
        minimumContributionInUSDT = _newMin;
        maximumContributionInUSDT = _newMax;
        emit LogMaxMinContributionChanged(_newMin, _newMax);
    }

    /**
     * @dev Fetches ETH price from chainlink oracle
     */
    function fetchETHPrice() public view returns (uint256) {
        (, int256 price, , , ) = chainlinkPriceFeedETH.latestRoundData();
        return toUint256(price);
    }

    /**
     * @dev Fetches USDT price from chainlink oracle
     */
    function fetchUSDTPrice() public view returns (uint256) {
        (, int256 price, , , ) = chainlinkPriceFeedUSDT.latestRoundData();
        uint256 ethUSD = fetchETHPrice();
        return toUint256(price).mul(ethUSD).div(1e18);
    }

    /**
     * @dev Casts int256 to uint256
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the BCUBE that will be allocated to the caller
     *
     * Requirements:
     * - dollarUnits >= minimumContributionInUSDT && dollarUnits <= maximumContributionInUSDT
     * - netSoldSHBTs <= HARD_CAP
     */
    function allocateSHBT(uint256 dollarUnits) private returns (uint256) {
        uint256 shbtAllocatedToUser;
        require(
            dollarUnits >= minimumContributionInUSDT,
            "Min contrbn not reached."
        );
        require(
            dollarUnits <= maximumContributionInUSDT,
            "Exceeds max contrbn limit"
        );
        uint256 totalContribution =
            allocatedSHBTRegistry[_msgSender()].dollarUnitsPayed.add(
                dollarUnits
            );
        shbtAllocatedToUser = SHBT_PRICE_PER_USDT.mul(dollarUnits);
        netSoldSHBTs = netSoldSHBTs.add(shbtAllocatedToUser);
        //solhint-disable-next-line reason-string
        require(netSoldSHBTs <= HARD_CAP, "SolhubTokenSale: Exceeds hard cap");
        // Updates dollarUnitsPayed in storage
        allocatedSHBTRegistry[_msgSender()]
            .dollarUnitsPayed = totalContribution;
        // Updates allocatedSHBT in storage
        allocatedSHBTRegistry[_msgSender()]
            .allocatedSHBT = allocatedSHBTRegistry[_msgSender()]
            .allocatedSHBT
            .add(shbtAllocatedToUser);
        return shbtAllocatedToUser;
    }
}
