// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title NewSolhubInvestor
/// @notice Token allocation contract for Investor
contract NewSolhubInvestor is Ownable, Pausable {
    /**
     * @dev Struct to store the investment type {SEED, STRATEGIC, PRIVATE}
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
        uint256 totalTokenAllocation;
    }

    /**
     * @dev Struct to store allocation details of investors
     * @param investmentTypeId Will be either of {SEED = 0, STRATEGIC = 1, PRIVATE = 2}
     * @param vestingDuration Number of months during which investment is possible
     * @param lockPeriod Number of months after which the investment starts
     * @param totalTokensAllocated Total tokens allocated for a specific round
     * @param totalTGETokens Number of TGE tokens the investor will get
     * @param totalTokensClaimed Number of tokens claimed by investor
     * @param dailyTokens Daily tokens the investor will get on claims
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
        uint256 dailyTokens;
        uint256 investmentTimestamp;
        bool isVesting;
        bool isTGETokenClaimed;
    }

    IERC20 public solhubTokenContract;

    mapping(uint256 => InvestmentType) internal investorsInvestmentType;
    mapping(address => mapping(uint8 => InvestorAllocation))
        public investorsInvestmentDetails;
    mapping(address => uint256[]) public alreadyWithdrawnDays;

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
            _investingIndex >= 0 && _investingIndex <= 2,
            "Invalid Invested Index"
        );
        _;
    }

    modifier onlyAfterTGE() {
        require(getCurrentTime() > getTGETime(), "TGE not yet started");
        _;
    }

    //TODO During upgradeability the constructor would be replaced by initialize()
    /**
     * @dev Sets the values for {solhubTokenAddress}
     */
    constructor(address solhubTokenAddress) {
        require(
            solhubTokenAddress != address(0),
            "SHUB address is address zero."
        );
        solhubTokenContract = IERC20(solhubTokenAddress);

        //SEED
        investorsInvestmentType[0] = InvestmentType(0, 12, 1, 5, 800000 ether);
        //STRATEGIC
        investorsInvestmentType[1] = InvestmentType(1, 12, 1, 5, 1000000 ether);
        //PRIVATE
        investorsInvestmentType[2] = InvestmentType(
            2,
            12,
            1,
            10,
            1400000 ether
        );
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
            uint256 dailyTokens = totalAllocation / 365;
            providedInvestmentAmount += _investedAmounts[i];
            addUserInvestmentDetails(
                _userAddresses[i],
                _investmentType,
                totalAllocation,
                investmentType.lockPeriod,
                investmentType.vestingDuration,
                tgeAmount,
                dailyTokens
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
    function pauseContract() external onlyOwner {
        _pause();
    }

    /**
     * @dev UnPauses the contract.
     *
     * Requirements:
     *
     * - can only be invoked by the owner of the contract
     */
    function unPauseContract() external onlyOwner {
        _unpause();
    }

    /**
     * @dev To get the invested tokens
     * @notice Check listingTimeOf all rounds + 30 days to be greater than current timestamp
     * Since, It is Linear Vesting over 12 Months, after 1 Month
     * @param _userAddress address of the User
     * @param _investingIndex index of the investing Type
     * @param _tokenAmount the amount of tokens user wishes to withdraw
     */
    //solhint-disable-next-line function-max-lines
    function claimVestingTokens(
        address _userAddress,
        uint8 _investingIndex,
        uint256 _tokenAmount
    )
        public
        onlyAfterTGE
        whenNotPaused
        checkVestingStatus(_userAddress, _investingIndex)
        returns (bool)
    {
        // Get Vesting Details
        InvestorAllocation memory investData = investorsInvestmentDetails[
            _userAddress
        ][_investingIndex];

        // Get total amount of tokens claimed till date
        uint256 _totalTokensClaimed = totalTokensClaimed(
            _userAddress,
            _investingIndex
        );
        // Get the total claimable token amount at the time of calling this function
        uint256 tokensToTransfer = calculateClaimableTokens(
            _userAddress,
            _investingIndex
        );
        require(tokensToTransfer > 0, "No tokens to transfer");
        //solhint-disable-next-line reason-string
        require(
            _tokenAmount <= tokensToTransfer,
            "Token amount cannot be greater than calimable amount"
        );
        uint256 contractTokenBalance = solhubTokenContract.balanceOf(
            address(this)
        );
        require(
            contractTokenBalance >= _tokenAmount,
            "Insufficient contract balance"
        );
        require(
            (_totalTokensClaimed + _tokenAmount) <=
                investData.totalTokensAllocated,
            "Cannot Claim more than Allocated"
        );

        investData.totalTokensClaimed += _tokenAmount;
        if (
            (_totalTokensClaimed + _tokenAmount) ==
            investData.totalTokensAllocated
        ) {
            investData.isVesting = false;
        }
        investorsInvestmentDetails[_userAddress][_investingIndex] = investData;
        return _sendTokens(_userAddress, _tokenAmount);
    }

    /**
     * @dev To get the TGE amount
     * @notice Checks whether listingTime of all rounds is greater than current timestamp
     * If yes, assigns TGE amount for that round to a variable {totalTGEAmountOfAllRounds}, and at last transfers the
     * sum of TGE of all rounds to the caller
     */
    function claimTGETokens(address _userAddress, uint8 _investingIndex)
        public
        onlyAfterTGE
        whenNotPaused
        checkVestingStatus(_userAddress, _investingIndex)
        returns (bool)
    {
        InvestorAllocation memory investData = investorsInvestmentDetails[
            _userAddress
        ][_investingIndex];
        uint256 tgeAmount = investData.totalTGETokens;
        investData.totalTokensClaimed += tgeAmount;
        investData.isTGETokenClaimed = true;
        require(tgeAmount > 0, "TGE withdraw already processed");

        uint256 contractTokenBalance = solhubTokenContract.balanceOf(
            address(this)
        );
        require(
            contractTokenBalance >= tgeAmount,
            "Insufficient contract balance"
        );
        investorsInvestmentDetails[_userAddress][_investingIndex] = investData;
        return _sendTokens(_userAddress, tgeAmount);
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
            "Locperiod not yet over"
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
            actualClaimableAmount = getDailyTokensAlreadyWithdrawnDays(
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
    function getDailyTokensAlreadyWithdrawnDays(
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
        uint256 dailyTokens = investorData.dailyTokens;


            uint256 rewardSeconds // solhint-disable-next-line not-rely-on-time
         = block.timestamp - investorData.investmentTimestamp;
        if (alreadyWithdrawnDays[_userAddress][_investmentIndex] == 0) {
            alreadyWithdrawnDays[_userAddress][_investmentIndex] =
                rewardSeconds /
                1 days;
            amount += (dailyTokens *
                alreadyWithdrawnDays[_userAddress][_investmentIndex]);
        } else {
            uint256 lastWithdrawnDays = alreadyWithdrawnDays[_userAddress][
                _investmentIndex
            ];
            alreadyWithdrawnDays[_userAddress][_investmentIndex] =
                rewardSeconds /
                1 days;
            amount +=
                dailyTokens *
                (alreadyWithdrawnDays[_userAddress][_investmentIndex] -
                    lastWithdrawnDays);
        }
        return amount;
    }

    /** @dev To initialize the InvestorAllocation struct
     * @param _userAddresses addresses of the User
     * @param _totalAllocation total amount to be lockedUp
     * @param _investmentIndex denotes the type of investment selected
     * @param _lockPeriod denotes the lock of the investment selected category
     * @param _vestingDuration denotes the total duration of the investment selcted category
     * @param _tgeAmount denotes the total TGE amount to be transferred
     * @param _dailyTokens Daily tokens the investor will get on claims
     */
    function addUserInvestmentDetails(
        address _userAddresses,
        uint8 _investmentIndex,
        uint256 _totalAllocation,
        uint8 _lockPeriod,
        uint8 _vestingDuration,
        uint256 _tgeAmount,
        uint256 _dailyTokens
    ) internal onlyValidInvestor(_userAddresses, _investmentIndex) {
        InvestorAllocation memory investorData = InvestorAllocation(
            _investmentIndex,
            _vestingDuration,
            _lockPeriod,
            _totalAllocation,
            _tgeAmount,
            0,
            _dailyTokens,
            //solhint-disable-next-line not-rely-on-time
            block.timestamp,
            true,
            false
        );
        investorsInvestmentDetails[_userAddresses][
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
        return 1624710715; // June 26, 2021 @ 6:02:00 PM
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
