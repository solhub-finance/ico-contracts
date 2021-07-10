// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "hardhat/console.sol";

/// @title NewVesting
/// @notice Token allocation contract for Investor
contract NewVesting is Ownable, Pausable {
    /**
     * @dev Struct to store the investment type
     * { MARKETING, ADVISORS, TEAM, RESERVES, MINING_REWARDS, EXCHANGE_LIQUIDITY, ECO_SYSTEM }
     * @param indexId Decimal representation of different rounds
     * @param vestingDuration Number of months during which investment is possible
     * @param lockPeriod Number of months after which the investment starts
     * @param tgePercent Percentage of tokens the user can claim after TGE (Token Generation Event)
     * @param totalTokenAllocation Total tokens allocated for a specific round
     */
    struct InvestmentType {
        uint8 indexId;
        uint8 vestingDuration;
        uint8 lockPeriod;
        uint8 tgePercent;
        uint8 monthlyPercent;
        uint256 totalTokenAllocation;
    }

    /**
     * @dev Struct to store allocation details of investors
     * @param investmentTypeId Will be either of
     * {
     *    MARKETING = 0, ADVISORS = 1, TEAM = 2, RESERVES = 3, MINING_REWARDS = 4,
     *    EXCHANGE_LIQUIDITY = 5, ECO_SYSTEM = 6
     * }
     * @param vestingDuration Number of months during which investment is possible
     * @param lockPeriod Number of months after which the investment starts
     * @param totalTokensAllocated Total tokens allocated for a specific round
     * @param totalTGETokens Number of TGE tokens the investor will get
     * @param totalTokensClaimed Number of tokens claimed by investor
     * @param monthlyTokens Monthly tokens the investor will get on claims
     * @param investmentTimestamp Timestamp when the investment was made
     * @param isTGETokenClaimed Boolean indicating whethe the investor has claimed TGE tokens
     */
    struct InvestorAllocation {
        uint8 investmentTypeId;
        uint8 vestingDuration;
        uint8 lockPeriod;
        uint256 totalTokensAllocated;
        uint256 totalTGETokens;
        uint256 totalTokensClaimed;
        uint256 monthlyTokens;
        uint256 investmentTimestamp;
        bool isVesting;
        bool isTGETokenClaimed;
    }

    IERC20 public solhubTokenContract;

    mapping(uint256 => InvestmentType) internal investorsInvestmentType;
    mapping(address => mapping(uint8 => InvestorAllocation))
        public investorsInvestmentDetails;

    mapping(address => uint256[7]) public alreadyWithdrawnMonths;

    modifier onlyValidInvestor(address _userAddresses, uint8 _investingIndex) {
        require(_userAddresses != address(0), "Invalid Address");
        require(
            !investorsInvestmentDetails[_userAddresses][_investingIndex]
                .isVesting,
            "Invested details already added"
        );
        _;
    }

    modifier checkVestingStatus(address _userAddresses, uint8 _investingIndex) {
        require(
            investorsInvestmentDetails[_userAddresses][_investingIndex]
                .isVesting,
            "Not added to investment index"
        );
        _;
    }

    modifier onlyValidInvestingIndex(uint8 _investingIndex) {
        require(
            _investingIndex >= 0 && _investingIndex <= 6,
            "Invalid Invested Index"
        );
        _;
    }

    modifier onlyAfterTGE() {
        require(getCurrentTime() > getTGETime(), "TGE not yet started");
        _;
    }

    /**
     * @dev Allows only the Owner to ADD an array of Addresses as well as their Invested Amount
     * - The array of user and amounts should be passed along with the InvestmentType Index.
     * - Thus, a particular batch of addresses shall be added under only one InvestmentType Index
     * @param _userAddresses array of addresses of the Users
     * @param _investedAmounts array of amounts to be vested
     * @param _investmentType allows the owner to select the type of investing category
     * @return - true if function executes successfully
     */
    //solhint-disable-next-line function-max-lines
    function addInvestmentDetails(
        address[] calldata _userAddresses,
        uint256[] calldata _investedAmounts,
        uint8 _investmentType
    )
        external
        onlyOwner
        onlyValidInvestingIndex(_investmentType)
        returns (bool)
    {
        require(
            _userAddresses.length == _investedAmounts.length,
            "Unequal arrays passed"
        );

        // Get Invested Category Details
        InvestmentType memory investmentType = investorsInvestmentType[
            _investmentType
        ];
        uint256 providedInvestmentAmount;
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            uint256 totalAllocation = _investedAmounts[i];
            uint256 tgeAmount = percentage(
                totalAllocation,
                investmentType.tgePercent
            );
            uint256 monthlyTokens = percentage(
                totalAllocation,
                investmentType.monthlyPercent
            );
            providedInvestmentAmount += _investedAmounts[i];
            addUserInvestmentDetails(
                _userAddresses[i],
                _investmentType,
                totalAllocation,
                investmentType.lockPeriod,
                investmentType.vestingDuration,
                tgeAmount,
                monthlyTokens
            );
        }
        uint256 ownerBalance = solhubTokenContract.balanceOf(owner());
        require(
            ownerBalance >= providedInvestmentAmount,
            "Insufficient owner balance"
        );
        solhubTokenContract.transferFrom(
            owner(),
            address(this),
            providedInvestmentAmount
        );
        return true;
    }

    /**
     * @dev Pauses the contract.
     *
     * Requirements:
     *
     * - can only be invoked by the owner of the contract
     */
    function pauseContract() external onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev UnPauses the contract.
     *
     * Requirements:
     *
     * - can only be invoked by the owner of the contract
     */
    function unPauseContract() external onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @dev Sets the values for {solhubTokenAddress}
     */
    //solhint-disable-next-line function-max-lines
    function initialize(address solhubTokenAddress) public {
        require(
            solhubTokenAddress != address(0),
            "SHUB address is address zero."
        );
        solhubTokenContract = IERC20(solhubTokenAddress);
        //Total SHUB = 1 Billion
        //MARKETING (10% of Total SHUB)
        /**
          uint8 indexId;
        uint8 vestingDuration;
        uint8 lockPeriod;
        uint8 tgePercent;
        uint8 monthlyPercent;
        uint256 totalTokenAllocation;
         */
        investorsInvestmentType[0] = InvestmentType(
            0,
            12,
            1,
            5,
            5,
            10_000_000_0 ether
        );
        //ADVISORS (3% of Total SHUB)
        investorsInvestmentType[1] = InvestmentType(
            1,
            12,
            6,
            0,
            5,
            3_000_000_0 ether
        );
        //TEAM (15% of Total SHUB)
        investorsInvestmentType[2] = InvestmentType(
            2,
            12,
            12,
            0,
            10,
            15_000_000_0 ether
        );
        //RESERVES (11.42% of Total SHUB)
        investorsInvestmentType[3] = InvestmentType(
            3,
            12,
            6,
            0,
            10,
            11_42_000_00 ether
        );
        //MINING_REWARDS (20% of Total SHUB)
        investorsInvestmentType[4] = InvestmentType(
            4,
            12,
            1,
            0,
            5,
            20_000_000_0 ether
        );
        //EXCHANGE_LIQUIDITY (2% of Total SHUB)
        investorsInvestmentType[5] = InvestmentType(
            5,
            0,
            0,
            100,
            0,
            2_000_000_0 ether
        );
        //ECO_SYSTEM (5% of Total SHUB)
        investorsInvestmentType[6] = InvestmentType(
            6,
            12,
            6,
            0,
            10,
            5_000_000_0 ether
        );
    }

    /**
     * @dev To get the invested tokens
     * @param _investmentType allows the owner to select the type of investing category
     * @return - true if function executes successfully
     */
    //solhint-disable-next-line function-max-lines
    function claimVestingTokens(uint8 _investmentType)
        public
        onlyAfterTGE
        whenNotPaused
        returns (bool)
    {
        //solhint-disable-next-line reason-string
        require(
            _investmentType != 5,
            "Invalid investment index, no vesting for Exchange & Liquidity"
        );
        uint256 tokensToTransfer = 0;
        InvestorAllocation memory investData = investorsInvestmentDetails[
            msg.sender
        ][_investmentType];
        if (investData.isVesting) {
            // Get total amount of tokens claimed till date
            uint256 _totalTokensClaimed = totalTokensClaimed(
                msg.sender,
                _investmentType
            );
            // Get the total claimable token amount at the time of calling this function
            uint256 claimableTokens = calculateClaimableTokens(
                msg.sender,
                _investmentType
            );
            if (claimableTokens > 0) {
                if (
                    (_totalTokensClaimed + claimableTokens) <=
                    investData.totalTokensAllocated
                ) {
                    investData.totalTokensClaimed += claimableTokens;
                    if (
                        (_totalTokensClaimed + claimableTokens) ==
                        investData.totalTokensAllocated
                    ) {
                        investData.isVesting = false;
                    }
                    investorsInvestmentDetails[msg.sender][
                        _investmentType
                    ] = investData;
                    tokensToTransfer += claimableTokens;
                }
            }
            // Else it implies that user has already withdrawn for the current day and should come tomorrow and
            // initiate vesting
        }
        require(tokensToTransfer > 0, "No tokens to transfer");
        uint256 contractTokenBalance = solhubTokenContract.balanceOf(
            address(this)
        );
        require(
            contractTokenBalance >= tokensToTransfer,
            "Insufficient contract balance"
        );
        return _sendTokens(msg.sender, tokensToTransfer);
    }

    /**
     * @dev To get the TGE amount
     * @param _investmentType allows the owner to select the type of investing category
     * @return - true if function executes successfully
     */
    function claimTGETokens(uint8 _investmentType)
        public
        onlyAfterTGE
        whenNotPaused
        returns (bool)
    {
        require(
            (_investmentType == 0 || _investmentType == 5),
            "Invalid investment index, no TGE"
        );
        uint256 tgeAmount = 0;
        InvestorAllocation memory investData = investorsInvestmentDetails[
            msg.sender
        ][_investmentType];
        if (investData.isVesting) {
            tgeAmount = investData.totalTGETokens;
            if (tgeAmount > 0 && !investData.isTGETokenClaimed) {
                investData.totalTokensClaimed += tgeAmount;
                investData.isTGETokenClaimed = true;
                investData.totalTGETokens = 0;
                investorsInvestmentDetails[msg.sender][
                    _investmentType
                ] = investData;
            }
        }
        uint256 contractTokenBalance = solhubTokenContract.balanceOf(
            address(this)
        );
        require(
            contractTokenBalance >= tgeAmount,
            "Insufficient contract balance"
        );
        require(tgeAmount > 0, "No tokens to transfer");
        return _sendTokens(msg.sender, tgeAmount);
    }

    /**
     * @dev Returns the total tokens claimed by an investor
     * @param _userAddresses address of the User
     * @param _investmentIndex index number of the investment type
     */
    function totalTokensClaimed(address _userAddresses, uint8 _investmentIndex)
        public
        view
        returns (uint256)
    {
        // Get Investment Details
        InvestorAllocation memory investorData = investorsInvestmentDetails[
            _userAddresses
        ][_investmentIndex];

        uint256 totalClaimedTokens = (investorData.totalTokensClaimed);

        if (investorData.isTGETokenClaimed) {
            totalClaimedTokens += investorData.totalTGETokens;
        }

        return totalClaimedTokens;
    }

    /**
     * @dev To calculate total claimable tokens at any given point of time
     * @param _userAddress address of the User
     * @param _investmentIndex index number of the investment type
     */
    //solhint-disable-next-line function-max-lines
    function calculateClaimableTokens(
        address _userAddress,
        uint8 _investmentIndex
    )
        internal
        checkVestingStatus(_userAddress, _investmentIndex)
        returns (uint256)
    {
        // Get Vesting Details
        InvestorAllocation memory investorData = investorsInvestmentDetails[
            _userAddress
        ][_investmentIndex];

        // Get Time Details
        uint256 actualClaimableAmount;
        uint256 timeElapsed = getCurrentTime() - getTGETime();

        // Get the Elapsed Days and Months
        uint256 totalMonthsElapsed = timeElapsed / monthInSeconds();
        uint256 totalDaysElapsed = timeElapsed / daysInSeconds();
        uint256 partialDaysElapsed = totalDaysElapsed % 30;

        if (partialDaysElapsed > 0 && totalMonthsElapsed > 0) {
            totalMonthsElapsed += 1;
        }

        //Check whether lock period is crossed
        require(
            totalMonthsElapsed > investorData.lockPeriod,
            "Cannot claim in lock period"
        );

        // If total duration of Vesting already crossed, return pending tokens to claimed
        if (totalMonthsElapsed > investorData.vestingDuration) {
            uint256 _totalTokensClaimed = totalTokensClaimed(
                _userAddress,
                _investmentIndex
            );
            actualClaimableAmount =
                investorData.totalTokensAllocated -
                _totalTokensClaimed;
        } else {
            actualClaimableAmount = getMonthlyTokensAlreadyWithdrawnMonths(
                _userAddress,
                _investmentIndex
            );
        }
        return actualClaimableAmount;
    }

    /**
     * @dev To transfer tokens from this contract to the user
     * @param _beneficiary address to which tokens will be sent
     * @param _amountOfTokens number of tokens to be transferred
     */
    function _sendTokens(address _beneficiary, uint256 _amountOfTokens)
        internal
        returns (bool)
    {
        solhubTokenContract.transfer(_beneficiary, _amountOfTokens);
        return true;
    }

    /**
     * @dev Returns the daily withdrawable number of tokens
     */
    function getMonthlyTokensAlreadyWithdrawnMonths(
        address _userAddress,
        uint8 _investmentIndex
    ) internal returns (uint256) {
        uint256 amount = 0;

        InvestorAllocation memory investorData = investorsInvestmentDetails[
            _userAddress
        ][_investmentIndex];
        require(
            investorData.totalTokensClaimed <=
                investorData.totalTokensAllocated,
            "No tokens to claim"
        );
        uint256 monthlyTokens = investorData.monthlyTokens;

        uint256 rewardSeconds = getCurrentTime() -
            investorData.investmentTimestamp;
        if (alreadyWithdrawnMonths[_userAddress][_investmentIndex] == 0) {
            alreadyWithdrawnMonths[_userAddress][_investmentIndex] =
                rewardSeconds /
                monthInSeconds();
            amount += (monthlyTokens *
                alreadyWithdrawnMonths[_userAddress][_investmentIndex]);
        } else {
            uint256 lastWithdrawnMonth = alreadyWithdrawnMonths[_userAddress][
                _investmentIndex
            ];
            alreadyWithdrawnMonths[_userAddress][_investmentIndex] =
                rewardSeconds /
                monthInSeconds();
            amount +=
                monthlyTokens *
                (alreadyWithdrawnMonths[_userAddress][_investmentIndex] -
                    lastWithdrawnMonth);
        }
        return amount;
    }

    /** @dev To initialize the InvestorAllocation struct
     * @param _userAddress addresses of the User
     * @param _totalAllocation total amount to be lockedUp
     * @param _investmentIndex denotes the type of investment selected
     * @param _lockPeriod denotes the lock of the investment selected category
     * @param _vestingDuration denotes the total duration of the investment selcted category
     * @param _tgeAmount denotes the total TGE amount to be transferred
     * @param _monthlyTokens Monthly tokens the investor will get on claims
     */
    function addUserInvestmentDetails(
        address _userAddress,
        uint8 _investmentIndex,
        uint256 _totalAllocation,
        uint8 _lockPeriod,
        uint8 _vestingDuration,
        uint256 _tgeAmount,
        uint256 _monthlyTokens
    ) internal onlyValidInvestor(_userAddress, _investmentIndex) {
        InvestorAllocation memory investorData = InvestorAllocation(
            _investmentIndex,
            _vestingDuration,
            _lockPeriod,
            _totalAllocation,
            _tgeAmount,
            0,
            _monthlyTokens,
            getCurrentTime(),
            true,
            false
        );
        investorsInvestmentDetails[_userAddress][
            _investmentIndex
        ] = investorData;
    }

    /**
     * @dev To return the current time
     */
    function getCurrentTime() internal view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }

    /**
     * @dev To return the TGE time
     */
    function getTGETime() internal pure returns (uint256) {
        return 1625979449; //Sunday, July 11, 2021 4:57:29 AM
    }

    /**
     * @dev To return seconds in a day
     */
    function daysInSeconds() internal pure returns (uint256) {
        return 86400;
    }

    /**
     * @dev To return seconds in a month
     */
    function monthInSeconds() internal pure returns (uint256) {
        return 2592000;
    }

    /**
     * @dev To calculate X%Y => X % Percentage of Y
     */
    function percentage(uint256 _totalAmount, uint256 _rate)
        internal
        pure
        returns (uint256)
    {
        return (_totalAmount * _rate) / 100;
    }
}
