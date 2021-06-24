// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title SolhubInvestor
/// @notice Token allocation contract for Investor
contract Vesting is Ownable {
    /**
     * @dev Struct to store the investment type
     * { MARKETING, ADVISORS, TEAM, RESERVES, MINING_REWARDS, EXCHANGE_LIQUIDITY & ECOSYSTEM }
     * @param indexId Decimal representation of different rounds
     * @param vestingDuration Number of months during which vesting is possible
     * @param lockPeriod Number of months after which the vesting starts
     * @param tgePercent Percentage of tokens the user can claim after TGE (Token Generation Event)
     * @param tokenPercent Percentage of totalTokenAllocation investor will get each month
     * @param totalTokenAllocation Total tokens allocated for a specific round
     * @param investmentTimestamp Timestamp when the investment was made
     */
    struct InvestmentType {
        uint8 indexId;
        uint8 vestingDuration;
        uint8 lockPeriod;
        uint8 tgePercent;
        uint8 tokenPercent;
        uint256 totalTokenAllocation;
        uint256 investmentTimestamp;
    }

    /**
     * @dev Struct to store allocation details of investors
     * @param investmentTypeId Will be either of the below items
     *{ 
        MARKETING = 0, ADVISORS = 1, TEAM = 2, RESERVES = 3,
        MINING_REWARDS = 4, EXCHANGE_LIQUIDITY = 5 & ECOSYSTEM = 6 
     *}
     * @param totalTokensAllocated Total tokens allocated for a specific round
     * @param totalTGETokens Number of TGE tokens the investor will get
     * @param totalTokensClaimed Number of tokens claimed by investor
     * @param isTGETokenClaimed Boolean indicating whethe the investor has claimed TGE tokens
     */
    struct InvestorAllocation {
        uint8 investmentTypeId;
        uint256 totalTokensAllocated;
        uint256 totalTGETokens;
        uint256 totalTokensClaimed;
        uint256 lastWithdrawnTimestamp;
        bool isTGETokenClaimed;
    }

    // Decimal representation of different rounds
    uint8 private constant MARKETING = 0;
    uint8 private constant ADVISORS = 1;
    uint8 private constant TEAM = 2;
    uint8 private constant RESERVES = 3;
    uint8 private constant MINING_REWARDS = 4;
    uint8 private constant EXCHANGE_LIQUIDITY = 5;
    uint8 private constant ECOSYSTEM = 6;

    // PERCENT ARE DEFINED IN TERMS OF 10000
    // i.e. 1% = 10000
    // The above representation becomes useful when calculating percentage of X in general
    uint256 private constant SCALING_FACTOR = 1_0000;
    uint256 private constant DIVISION_FACTOR = 1_000_000;
    uint256 private constant DAYS_IN_YEAR = 365;

    IERC20 public solhubTokenContract;

    mapping(address => mapping(uint8 => InvestmentType))
        public investorsInvestmentType;
    mapping(address => mapping(uint8 => InvestorAllocation))
        public investorsInvestmentDetails;
    mapping(uint8 => uint256) public listingTimeOf;

    // Since there are multiple rounds and each round has a different lock period thus,
    // instead of modifier it will be covered using require statements

    /**
     * @dev Sets the values for {solhubTokenAddress}
     */
    constructor(address solhubTokenAddress) {
        require(
            solhubTokenAddress != address(0),
            "SHUB address is address zero."
        );
        solhubTokenContract = IERC20(solhubTokenAddress);
    }

    /**
     * @dev To set listing time for different rounds
     * After TGE owner will call this function to set listing time for that particular round
     *
     * Requirements:
     * - invocation can be done, only by the contract owner.
     */
    function setListingTime(
        uint8[] memory _rounds,
        uint256[] memory _listingTimestamps
    ) public onlyOwner {
        require(_rounds.length == _listingTimestamps.length, "Params mismatch");
        for (uint256 i = 0; i < _rounds.length; i++) {
            require(_rounds[i] < 7, "Round cannot exceed 7");
            require(
                // solhint-disable-next-line not-rely-on-time
                _listingTimestamps[i] > block.timestamp,
                "Listing time is in the past"
            );
            listingTimeOf[_rounds[i]] = _listingTimestamps[i];
        }
    }

    /**
     * @dev Assign given number of tokens to an Investor for a specific round
     *
     * Requirements:
     * - invocation can be done, only by the contract owner.
     */
    function transferSHUBTo(
        address _investor,
        uint256 _noOfSHUBs,
        uint8 _round
    ) public onlyOwner {
        require(_round < 7, "Round cannot exceed 7");
        require(_investor != address(0), "Investor is address zero");
        require(_noOfSHUBs > 0, "SHUBs must be greater than 0");
        updateInvestmentInfo(_investor, _noOfSHUBs, _round);
    }

    /**
     * @dev To get the TGE amount
     * @notice Claims TGE tokens only for MARKETING as only that has tgePercent of 5%
     */
    function claimTGETokens() public {
        // solhint-disable-next-line not-rely-on-time
        require(listingTimeOf[MARKETING] > block.timestamp, "TGE not announced");
        uint256 amount = 0;
        if (!investorsInvestmentDetails[msg.sender][MARKETING].isTGETokenClaimed) {
            InvestorAllocation storage investorAllocation = investorsInvestmentDetails[msg.sender][MARKETING];
            amount = investorAllocation.totalTGETokens;
            investorAllocation.totalTokensClaimed += amount;
            investorAllocation.isTGETokenClaimed = true;
        }
        require(
            amount > 0,
            "TGE withdraw already processed"
        );
        require(
            solhubTokenContract.transferFrom(
                owner(),
                msg.sender,
                amount
            ),
            "Withdraw TGE failed"
        );
    }

    /**
     * @dev To get the invested tokens
     */
    function claimVestingTokens(uint8 round) public {
        InvestorAllocation storage investorAllocation = investorsInvestmentDetails[msg.sender][round];
        InvestmentType memory investmentType = investorsInvestmentType[msg.sender][round];
        require(investorAllocation.totalTokensClaimed <= investorAllocation.totalTokensAllocated, "No tokens to claim");
        uint256 withdrawalAmt = claimTokens(investorAllocation, investmentType);
        require(withdrawalAmt > 0, "Withdrawal already processed");
        // solhint-disable-next-line not-rely-on-time
        investorAllocation.lastWithdrawnTimestamp = block.timestamp;
        investorAllocation.totalTokensClaimed += withdrawalAmt;
        require(
            solhubTokenContract.transferFrom(
                owner(),
                msg.sender,
                withdrawalAmt
            ),
            "Withdraw Vesting Tokens failed"
        );
    }

    /**
     * @dev To update SEED investment information
     */
     function updateInvestmentInfo(address _investor, uint256 _noOfSHUBs, uint8 _round) internal {
        (
            uint8 _indexId,
            uint8 _vestingDuration,
            uint8 _lockPeriod,
            uint8 _tgePercent,
            uint8 _tokenPercent
        ) = getRoundConstants(_round);

        // Since only MARKETING round has TGE & MARKETING is round 0
        bool _isTGETokenClaimed = false;
        if(_round != 0) {
            _isTGETokenClaimed = true;
        }

        uint256 investmentAmount = 
                investorsInvestmentDetails[_investor][_round].totalTokensAllocated +
                _noOfSHUBs;
            // Update InvestmentType
            investorsInvestmentType[_investor][_indexId] = InvestmentType({
                indexId: _indexId,
                vestingDuration: _vestingDuration,
                lockPeriod: _lockPeriod,
                tgePercent: _tgePercent,
                tokenPercent: _tokenPercent,
                totalTokenAllocation: investmentAmount,
                // solhint-disable-next-line not-rely-on-time
                investmentTimestamp: block.timestamp
            });
            // Update InvestorAllocation
            investorsInvestmentDetails[_investor][_indexId] = InvestorAllocation({
                investmentTypeId: _indexId,
                totalTokensAllocated: investmentAmount,
                totalTGETokens: getTokensBasedOnPercent(investmentAmount, _tgePercent),
                totalTokensClaimed: 0,
                isTGETokenClaimed: _isTGETokenClaimed,
                // solhint-disable-next-line not-rely-on-time
                lastWithdrawnTimestamp: 0
            });
     }

    /**
    * @dev To calculate the marketing tokens
    */
    function claimTokens(
        InvestorAllocation memory investorAllocation,
        InvestmentType memory investmentType
    ) 
    internal
    view
    returns
    (uint256)
    {
        uint8 lockPeriod = investmentType.lockPeriod;
        uint256 investmentTimestamp = investmentType.investmentTimestamp;
        uint256 lastWithdrawnTimestamp = investorAllocation.lastWithdrawnTimestamp;
        // solhint-disable-next-line not-rely-on-time
        require(((block.timestamp - investmentTimestamp) / 30 days) >= lockPeriod, "Cannot claim in lock period");
        // solhint-disable-next-line not-rely-on-time
        require((block.timestamp - lastWithdrawnTimestamp) >= 1, "Wait for 1 month, then claim");
        uint256 claimableAmount = getTokensBasedOnPercent(
            investorAllocation.totalTokensAllocated, investmentType.tokenPercent
        );
        return claimableAmount;
    }

    /**
     * @dev To return InvestmentType indexId
     * @notice When ROUND is MARKETING then indexId = 0
     * When ROUND is ADVISORS then indexId = 1
     * When ROUND is TEAM then indexId = 2
     * When ROUND is RESERVES then indexId = 3
     * When ROUND is MINING_REWARDS then indexId = 4
     * When ROUND is EXCHANGE_LIQUIDITY then indexId = 5
     * When ROUND is ECOSYSTEM then indexId = 6
     */
    function getRoundConstants(uint8 round)
        internal
        pure
        returns (
            uint8 _indexId,
            uint8 _vestingDuration,
            uint8 _lockPeriod,
            uint8 _tgePercent,
            uint8 _tokenPercent
        )
    {
        if (round == MARKETING) {
            return (0, 12, 1, 5, 5);
        } else if (round == ADVISORS) {
            return (1, 12, 6, 0, 5);
        } else if (round == TEAM) {
            return (2, 12, 12, 0, 10);
        } else if (round == RESERVES) {
            return (3, 12, 6, 0, 10);
        } else if (round == MINING_REWARDS) {
            return (4, 12, 1, 0, 5);
        } else if (round == EXCHANGE_LIQUIDITY) {
            return (5, 12, 0, 0, 100);
        } else {
            return (6, 12, 6, 0, 10);
        }
    }

    /**
     * @dev To calculate TGE tokens for a specifc round
     */
     function getTokensBasedOnPercent(uint256 investmenAmount, uint8 tokenPercent) internal pure returns (uint256) {
        return (( investmenAmount * (tokenPercent * SCALING_FACTOR)) / DIVISION_FACTOR);
     }

}
