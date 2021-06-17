// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title SolhubInvestor
/// @notice Token allocation contract for Investor
contract SolhubInvestor is Ownable {
    /**
     * @dev Struct to store all rounds investment details for an investor
     * @param seedInvAmt Amount invested in the SEED round
     * @param seedTGEAmt TGE amount for SEED round
     * @param strategicInvAmt Amount invested in the STRATEGIC round
     * @param strategicTGEAmt TGE amount for STRATEGIC round
     * @param privateInvAmt Amount invested in the PRIVATE round
     * @param privateTGEAmt TGE amount for PRIVATE round
     */
    struct InvestorInfo {
        uint256 seedInvTimestamp;
        uint256 seedInvAmt;
        uint256 seedTGEAmt;
        uint256 strategicInvTimestamp;
        uint256 strategicInvAmt;
        uint256 strategicTGEAmt;
        uint256 privateInvTimestamp;
        uint256 privateInvAmt;
        uint256 privateTGEAmt;
    }

    enum ROUNDS {SEED, STRATEGIC, PRIVATE}

    // PERCENT ARE DEFINED IN TERMS OF 10000
    // i.e. 1% = 10000
    uint256 public constant SEED_OR_STRATEGIC_TGE_PERCENT = 5_0000;
    uint256 public constant PRIVATE_TGE_PERCENT = 10_0000;
    uint256 public constant DIVISION_FACTOR = 1_000_000;
    uint256 public constant DAYS_IN_YEAR = 365;

    IERC20 public solhubTokenContract;

    mapping(address => InvestorInfo) public invDetails;
    mapping(ROUNDS => uint256) public listingTimeOf;
    mapping(address => uint256[]) public alreadyWithdrawnDays;

    modifier isTGEAnnounced() {
        require(
            // solhint-disable-next-line not-rely-on-time
            (listingTimeOf[ROUNDS.SEED] > block.timestamp) ||
                // solhint-disable-next-line not-rely-on-time
                (listingTimeOf[ROUNDS.STRATEGIC] > block.timestamp) ||
                // solhint-disable-next-line not-rely-on-time
                (listingTimeOf[ROUNDS.PRIVATE] > block.timestamp),
            "TGE not announced"
        );
        _;
    }

    modifier canWithdraw() {
        require(
            // solhint-disable-next-line not-rely-on-time
            ((listingTimeOf[ROUNDS.SEED] + 30 days) > block.timestamp) ||
                ((listingTimeOf[ROUNDS.STRATEGIC] + 30 days) >
                    // solhint-disable-next-line not-rely-on-time
                    block.timestamp) ||
                // solhint-disable-next-line not-rely-on-time
                ((listingTimeOf[ROUNDS.PRIVATE] + 30 days) > block.timestamp),
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
     * @dev Assign given number of tokens to an Investor for a specific round
     *
     * Requirements:
     * - invocation can be done, only by the contract owner.
     */
    function transferSHBTTo(
        address _investor,
        uint256 _noOfSHBTs,
        ROUNDS _round
    ) public onlyOwner {
        require(uint8(_round) < 3, "Round cannot exceed 3");
        require(_investor != address(0), "Wallet is address zero");
        require(_noOfSHBTs > 0, "SHBTs must be greater than 0");
        uint256 invAmt = 0;
        if (ROUNDS.SEED == _round) {
            invAmt = invDetails[_investor].seedInvAmt;
            // Update investment in storage
            invDetails[_investor].seedInvAmt += _noOfSHBTs;
            // calculate TGE
            invDetails[_investor].seedTGEAmt =
                (invAmt * SEED_OR_STRATEGIC_TGE_PERCENT) /
                DIVISION_FACTOR;
            // solhint-disable-next-line not-rely-on-time
            invDetails[_investor].seedInvTimestamp = block.timestamp;
        } else if (ROUNDS.STRATEGIC == _round) {
            invAmt = invDetails[_investor].strategicInvAmt;
            // Update investment in storage
            invDetails[_investor].strategicInvAmt += _noOfSHBTs;
            // calculate TGE
            invDetails[_investor].strategicTGEAmt =
                (invAmt * SEED_OR_STRATEGIC_TGE_PERCENT) /
                DIVISION_FACTOR;
            // solhint-disable-next-line not-rely-on-time
            invDetails[_investor].strategicInvTimestamp = block.timestamp;
        } else {
            invAmt = invDetails[_investor].privateInvAmt;
            // Update investment in storage
            invDetails[_investor].privateInvAmt += _noOfSHBTs;
            // calculate TGE
            invDetails[_investor].privateTGEAmt =
                (invAmt * PRIVATE_TGE_PERCENT) /
                DIVISION_FACTOR;
            // solhint-disable-next-line not-rely-on-time
            invDetails[_investor].privateInvTimestamp = block.timestamp;
        }
    }

    /**
     * @dev To set listing time for different rounds
     * After TGE owner will call this function to set listing time for that particular round
     *
     * Requirements:
     * - invocation can be done, only by the contract owner.
     */
    function setListingTime(ROUNDS _round, uint256 _listingTimestamp)
        public
        onlyOwner
    {
        require(uint8(_round) < 3, "Round cannot exceed 3");
        listingTimeOf[_round] = _listingTimestamp;
    }

    /**
     * @dev To get the TGE amount
     * @notice Checks whether listingTime of all rounds is greater than current timestamp
     * If yes, assigns TGE amount for that round to a variable {totalTGEAmountOfAllRounds}, and at last transfers the
     * sum of TGE of all rounds to the caller
     */
    function withdrawTGEAmount() public isTGEAnnounced {
        uint256 totalTGEAmountOfAllRounds = 0;
        if (
            // solhint-disable-next-line not-rely-on-time
            (listingTimeOf[ROUNDS.SEED] > block.timestamp) &&
            invDetails[msg.sender].seedTGEAmt > 0
        ) {
            totalTGEAmountOfAllRounds += invDetails[msg.sender].seedTGEAmt;
            invDetails[msg.sender].seedTGEAmt = 0;
        }
        if (
            // solhint-disable-next-line not-rely-on-time
            (listingTimeOf[ROUNDS.STRATEGIC] > block.timestamp) &&
            invDetails[msg.sender].strategicTGEAmt > 0
        ) {
            totalTGEAmountOfAllRounds += invDetails[msg.sender].strategicTGEAmt;
            invDetails[msg.sender].strategicTGEAmt = 0;
        }
        if (
            // solhint-disable-next-line not-rely-on-time
            (listingTimeOf[ROUNDS.PRIVATE] > block.timestamp) &&
            invDetails[msg.sender].privateTGEAmt > 0
        ) {
            totalTGEAmountOfAllRounds += invDetails[msg.sender].privateTGEAmt;
            invDetails[msg.sender].privateTGEAmt = 0;
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
    function withdrawLinearly() public canWithdraw {
        uint256 withdrawalAmt = 0;
        withdrawalAmt += withdrawSeedLinear();
        withdrawalAmt += withdrawStrategicLinear();
        withdrawalAmt += withdrawPrivateLinear();
        require(withdrawalAmt > 0, "Withdrawal already processed");
        require(
            solhubTokenContract.transferFrom(
                owner(),
                msg.sender,
                withdrawalAmt
            ),
            "Withdraw TGE failed"
        );
    }

    /**
     * @dev Returns the withdrawal amount for Seed round
     */
    function withdrawSeedLinear() internal returns (uint256) {
        uint256 amount = 0;
        uint256 oneDaySeedAmt =
            invDetails[msg.sender].seedInvAmt / DAYS_IN_YEAR;
        uint256 rewardSeconds =
            // solhint-disable-next-line not-rely-on-time
            block.timestamp - invDetails[msg.sender].seedInvTimestamp;
        if (alreadyWithdrawnDays[msg.sender][0] == 0) {
            alreadyWithdrawnDays[msg.sender][0] = rewardSeconds / 1 days;
            amount += (oneDaySeedAmt * alreadyWithdrawnDays[msg.sender][0]);
        } else {
            uint256 lastWithdrawnDays = alreadyWithdrawnDays[msg.sender][0];
            alreadyWithdrawnDays[msg.sender][0] = rewardSeconds / 1 days;
            amount +=
                oneDaySeedAmt *
                (alreadyWithdrawnDays[msg.sender][0] - lastWithdrawnDays);
        }
        invDetails[msg.sender].seedInvAmt -= amount;
        return amount;
    }

    /**
     * @dev Returns the withdrawal amount for Strategic round
     */
    function withdrawStrategicLinear() internal returns (uint256) {
        uint256 amount = 0;
        uint256 oneDayStratAmt =
            invDetails[msg.sender].strategicInvAmt / DAYS_IN_YEAR;
        uint256 rewardSeconds =
            // solhint-disable-next-line not-rely-on-time
            block.timestamp - invDetails[msg.sender].strategicInvTimestamp;
        if (alreadyWithdrawnDays[msg.sender][1] == 0) {
            alreadyWithdrawnDays[msg.sender][1] = rewardSeconds / 1 days;
            amount += (oneDayStratAmt * alreadyWithdrawnDays[msg.sender][1]);
        } else {
            uint256 lastWithdrawnDays = alreadyWithdrawnDays[msg.sender][1];
            alreadyWithdrawnDays[msg.sender][1] = rewardSeconds / 1 days;
            amount += (oneDayStratAmt *
                (alreadyWithdrawnDays[msg.sender][1] - lastWithdrawnDays));
        }
        invDetails[msg.sender].strategicInvAmt -= amount;
        return amount;
    }

    /**
     * @dev Returns the withdrawal amount for Private round
     */
    function withdrawPrivateLinear() internal returns (uint256) {
        uint256 amount = 0;
        uint256 oneDayPrivateAmt =
            invDetails[msg.sender].privateInvAmt / DAYS_IN_YEAR;
        uint256 rewardSeconds =
            // solhint-disable-next-line not-rely-on-time
            block.timestamp - invDetails[msg.sender].privateInvTimestamp;
        if (alreadyWithdrawnDays[msg.sender][2] == 0) {
            alreadyWithdrawnDays[msg.sender][2] = rewardSeconds / 1 days;
            amount += (oneDayPrivateAmt * alreadyWithdrawnDays[msg.sender][2]);
        } else {
            uint256 lastWithdrawnDays = alreadyWithdrawnDays[msg.sender][2];
            alreadyWithdrawnDays[msg.sender][2] = rewardSeconds / 1 days;
            amount += (oneDayPrivateAmt *
                (alreadyWithdrawnDays[msg.sender][2] - lastWithdrawnDays));
        }
        invDetails[msg.sender].privateInvAmt -= amount;
        return amount;
    }
}
