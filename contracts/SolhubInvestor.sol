// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title SolhubInvestor
/// @notice Token allocation contract for Investor
contract SolhubInvestor is Ownable {
    /**
     * @dev Struct to store the investment type {SEED, STRATEGIC, PRIVATE}
     * @param indexId Decimal representation of different rounds
     * @param vestingDuration Number of months during which vesting is possible
     * @param lockPeriod Number of days after which the vesting starts
     * @param tgePercent Percentage of tokens the user can claim after TGE (Token Generation Event)
     * @param totalTokenAllocation Total tokens allocated for a specific round
     * @param dailyTokens Daily tokens the investor will get on claims
     * @param investmentTimestamp Timestamp when the investment was made
     */
    struct InvestmentType {
        uint8 indexId;
        uint8 vestingDuration;
        uint8 lockPeriod;
        uint8 tgePercent;
        uint256 totalTokenAllocation;
        uint256 dailyTokens;
        uint256 investmentTimestamp;
    }

    /**
     * @dev Struct to store allocation details of investors
     * @param investmentTypeId Will be either of {SEED = 0, STRATEGIC = 1, PRIVATE = 2}
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
        bool isTGETokenClaimed;
    }

    // Decimal representation of different rounds
    uint8 private constant SEED = 0;
    uint8 private constant STRATEGIC = 1;
    uint8 private constant PRIVATE = 2;

    // PERCENT ARE DEFINED IN TERMS OF 10000
    // i.e. 1% = 10000
    // The above representation becomes useful when calculation percentage of X in general
    uint256 private constant SCALING_FACTOR = 1_0000;
    uint256 private constant DIVISION_FACTOR = 1_000_000;
    uint256 private constant DAYS_IN_YEAR = 365;

    IERC20 public solhubTokenContract;

    mapping(address => mapping(uint8 => InvestmentType))
        public investorsInvestmentType;
    mapping(address => mapping(uint8 => InvestorAllocation)) public investorsInvestmentDetails;
    mapping(uint8 => uint256) public listingTimeOf;
    mapping(address => uint256[]) public alreadyWithdrawnDays;

    modifier isTGEAnnounced() {
        require(
            // solhint-disable-next-line not-rely-on-time
            (listingTimeOf[SEED] > block.timestamp) ||
                // solhint-disable-next-line not-rely-on-time
                (listingTimeOf[STRATEGIC] > block.timestamp) ||
                // solhint-disable-next-line not-rely-on-time
                (listingTimeOf[PRIVATE] > block.timestamp),
            "TGE not announced"
        );
        _;
    }

    modifier canClaim() {
        require(
            // solhint-disable-next-line not-rely-on-time
            ((listingTimeOf[SEED] + 30 days) > block.timestamp) ||
                ((listingTimeOf[STRATEGIC] + 30 days) >
                    // solhint-disable-next-line not-rely-on-time
                    block.timestamp) ||
                // solhint-disable-next-line not-rely-on-time
                ((listingTimeOf[PRIVATE] + 30 days) > block.timestamp),
            "Cannot withdraw"
        );
        _;
    }

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
    function setListingTime(uint8 _round, uint256 _listingTimestamp)
        public
        onlyOwner
    {
        require(_round < 3, "Round cannot exceed 3");
        listingTimeOf[_round] = _listingTimestamp;
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
        require(_round < 3, "Round cannot exceed 3");
        require(_investor != address(0), "Investor is address zero");
        require(_noOfSHUBs > 0, "SHUBs must be greater than 0");
        updateInvestmentInfo(_investor, _noOfSHUBs, _round);
    }

    /**
     * @dev To get the TGE amount
     * @notice Checks whether listingTime of all rounds is greater than current timestamp
     * If yes, assigns TGE amount for that round to a variable {totalTGEAmountOfAllRounds}, and at last transfers the
     * sum of TGE of all rounds to the caller
     */
    function claimTGETokens() public isTGEAnnounced {
        uint256 totalTGEAmountOfAllRounds = 0;
        if (
            // solhint-disable-next-line not-rely-on-time
            (listingTimeOf[SEED] > block.timestamp &&
            !investorsInvestmentDetails[msg.sender][SEED].isTGETokenClaimed)
        ) {
            totalTGEAmountOfAllRounds += updateTGEStorage(msg.sender, SEED);
        }

        if (
            // solhint-disable-next-line not-rely-on-time
            (listingTimeOf[STRATEGIC] > block.timestamp &&
            !investorsInvestmentDetails[msg.sender][STRATEGIC].isTGETokenClaimed)
        ) {
            totalTGEAmountOfAllRounds += updateTGEStorage(msg.sender, STRATEGIC);
        }

         if (
            // solhint-disable-next-line not-rely-on-time
            (listingTimeOf[PRIVATE] > block.timestamp &&
            !investorsInvestmentDetails[msg.sender][PRIVATE].isTGETokenClaimed)
        ) {
            totalTGEAmountOfAllRounds += updateTGEStorage(msg.sender, PRIVATE);
        }
        require(
            totalTGEAmountOfAllRounds > 0,
            "TGE withdraw already processed"
        );
        require(
            solhubTokenContract.transferFrom(
                owner(),
                msg.sender,
                totalTGEAmountOfAllRounds
            ),
            "Withdraw TGE failed"
        );
    }

     /**
     * @dev To get the invested tokens
     * @notice Check listingTimeOf all rounds + 30 days to be greater than current timestamp
     * Since, It is Linear Vesting over 12 Months, after 1 Month
     */
    function claimVestingTokens() public canClaim {
        uint256 withdrawalAmt = 0;
        withdrawalAmt += claimTokens(SEED, 0);
        withdrawalAmt += claimTokens(STRATEGIC, 1);
        withdrawalAmt += claimTokens(PRIVATE, 2);
        require(withdrawalAmt > 0, "Withdrawal already processed");
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
     * @dev Returns the withdrawal amount for Seed round
     */
    function claimTokens(uint8 _round, uint8 _alreadyWithdrawnIndex) internal returns (uint256) {
        uint256 amount = 0;
        uint256 dailyTokens = investorsInvestmentType[msg.sender][_round].dailyTokens;
        uint256 rewardSeconds =
            // solhint-disable-next-line not-rely-on-time
            block.timestamp - investorsInvestmentType[msg.sender][_round].investmentTimestamp;
        if (alreadyWithdrawnDays[msg.sender][_alreadyWithdrawnIndex] == 0) {
            alreadyWithdrawnDays[msg.sender][_alreadyWithdrawnIndex] = rewardSeconds / 1 days;
            amount += (dailyTokens * alreadyWithdrawnDays[msg.sender][_alreadyWithdrawnIndex]);
        } else {
            uint256 lastWithdrawnDays = alreadyWithdrawnDays[msg.sender][_alreadyWithdrawnIndex];
            alreadyWithdrawnDays[msg.sender][_alreadyWithdrawnIndex] = rewardSeconds / 1 days;
            amount +=
                dailyTokens *
                (alreadyWithdrawnDays[msg.sender][_alreadyWithdrawnIndex] - lastWithdrawnDays);
        }
        investorsInvestmentDetails[msg.sender][_round].totalTokensClaimed += amount;
        return amount;
    }

    /**
     * @dev To update TGE storage variables
     */
     function updateTGEStorage(address _investor, uint8 round) internal returns (uint256) {
        InvestorAllocation storage investorAllocation = investorsInvestmentDetails[_investor][round];
        uint256 tgeAmount = investorAllocation.totalTGETokens;
        investorAllocation.totalTokensClaimed += tgeAmount;
        investorAllocation.isTGETokenClaimed = true;
        return tgeAmount;
    }

    /**
     * @dev To update SEED investment information
     */
     function updateInvestmentInfo(address _investor, uint256 _noOfSHUBs, uint8 _round) internal {
        (
            uint8 _indexId,
            uint8 _vestingDuration,
            uint8 _lockPeriod,
            uint8 _tgePercent
        ) = getRoundConstants(_round);
        uint256 investmentAmount = 
                investorsInvestmentDetails[_investor][_round].totalTokensAllocated +
                _noOfSHUBs;
            // Update InvestmentType
            investorsInvestmentType[_investor][_indexId] = InvestmentType({
                indexId: _indexId,
                vestingDuration: _vestingDuration,
                lockPeriod: _lockPeriod,
                tgePercent: _tgePercent,
                totalTokenAllocation: investmentAmount,
                dailyTokens: (investmentAmount / DAYS_IN_YEAR),
                // solhint-disable-next-line not-rely-on-time
                investmentTimestamp: block.timestamp
            });
            // Update InvestorAllocation
            investorsInvestmentDetails[_investor][_indexId] = InvestorAllocation({
                investmentTypeId: _indexId,
                totalTokensAllocated: investmentAmount,
                totalTGETokens: getTGETokens(investmentAmount, _tgePercent),
                totalTokensClaimed: 0,
                isTGETokenClaimed: false
            });
     }

    /**
     * @dev To return InvestmentType indexId
     * @notice When ROUND is SEED then indexId = 0
     * When ROUND is STRATEGIC then indexId = 1
     * When ROUND is PRIVATE then indexId = 2
     */
    function getRoundConstants(uint8 round)
        internal
        pure
        returns (
            uint8 _indexId,
            uint8 _vestingDuration,
            uint8 _lockPeriod,
            uint8 _tgePercent
        )
    {
        if (round == SEED) {
            return (0, 12, 1, 5);
        } else if (round == STRATEGIC) {
            return (1, 12, 1, 5);
        } else {
            return (2, 12, 1, 10);
        }
    }

    /**
     * @dev To calculate TGE tokens for a specifc round
     */
     function getTGETokens(uint256 investmenAmount, uint8 tgePercent) internal pure returns (uint256) {
        return (( investmenAmount * (tgePercent * SCALING_FACTOR)) / DIVISION_FACTOR);
     }
}
