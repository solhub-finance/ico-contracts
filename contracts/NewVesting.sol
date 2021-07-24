// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "hardhat/console.sol";

/// @title NewVesting
/// @notice Token allocation contract for Vesting
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
    struct VestingType {
        uint8 indexId;
        uint8 vestingDuration;
        uint8 lockPeriod;
        uint8 tgePercent;
        uint8 monthlyPercent;
        uint256 totalTokenAllocation;
    }

    /**
     * @dev Struct to store allocation details of investors
     * @param vestingTypeId Will be either of
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
     * @param vestor Address of the vestor
     * @param isTGETokenClaimed Boolean indicating whethe the investor has claimed TGE tokens
     */
    struct VestingAllocation {
        uint8 vestingTypeId;
        uint8 vestingDuration;
        uint8 lockPeriod;
        uint256 totalTokensAllocated;
        uint256 totalTGETokens;
        uint256 totalTokensClaimed;
        uint256 monthlyTokens;
        uint256 investmentTimestamp;
        address vestor;
        bool isVesting;
        bool isTGETokenClaimed;
    }

    IERC20 public solhubTokenContract;

    mapping(uint256 => VestingType) internal vestingType;
    mapping(address => VestingAllocation) public vestingDetails;

    modifier checkVestingStatus(address _userAddresses) {
        require(
            vestingDetails[_userAddresses].isVesting,
            "Not added to vesting index"
        );
        _;
    }

    modifier onlyAfterTGE() {
        require(getCurrentTime() > getTGETime(), "TGE not yet started");
        _;
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
    function initialize(address solhubTokenAddress, address[7] memory _vestors)
        public
    {
        require(
            solhubTokenAddress != address(0),
            "SHUB address is address zero."
        );
        //Total SHUB = 200 Million => 200_000_000 ether
        solhubTokenContract = IERC20(solhubTokenAddress);

        VestingAllocation memory vestingData;
        uint256 totalVestingAmount = 0;

        //MARKETING (10% of Total SHUB)
        vestingType[0] = VestingType(0, 12, 1, 5, 5, 20_000_000 ether);
        vestingData = VestingAllocation({
            vestingTypeId: 0,
            vestingDuration: 12,
            lockPeriod: 1,
            totalTokensAllocated: 20_000_000 ether,
            totalTGETokens: (20_000_000 ether * 5) / 100,
            totalTokensClaimed: 0,
            monthlyTokens: (20_000_000 ether * 5) / 100,
            investmentTimestamp: 1625979449, // TGE TIME
            vestor: _vestors[0],
            isVesting: true,
            isTGETokenClaimed: false
        });
        vestingDetails[_vestors[0]] = vestingData;
        totalVestingAmount += 20_000_000 ether;

        //ADVISORS (3% of Total SHUB)
        vestingType[1] = VestingType(1, 12, 6, 0, 5, 60_000_000 ether);
        vestingData = VestingAllocation({
            vestingTypeId: 1,
            vestingDuration: 12,
            lockPeriod: 6,
            totalTokensAllocated: 60_000_000 ether,
            totalTGETokens: 0,
            totalTokensClaimed: 0,
            monthlyTokens: (60_000_000 ether * 5) / 100,
            investmentTimestamp: 1625979449, // TGE TIME
            vestor: _vestors[1],
            isVesting: true,
            isTGETokenClaimed: false
        });
        vestingDetails[_vestors[1]] = vestingData;
        totalVestingAmount += 60_000_000 ether;

        //TEAM (15% of Total SHUB)
        vestingType[2] = VestingType(2, 12, 12, 0, 10, 30_000_000 ether);
        vestingData = VestingAllocation({
            vestingTypeId: 2,
            vestingDuration: 12,
            lockPeriod: 12,
            totalTokensAllocated: 30_000_000 ether,
            totalTGETokens: 0,
            totalTokensClaimed: 0,
            monthlyTokens: (30_000_000 ether * 10) / 100,
            investmentTimestamp: 1625979449, // TGE TIME
            vestor: _vestors[2],
            isVesting: true,
            isTGETokenClaimed: false
        });
        vestingDetails[_vestors[2]] = vestingData;
        totalVestingAmount += 30_000_000 ether;

        //RESERVES (11.42% of Total SHUB)
        vestingType[3] = VestingType(3, 12, 6, 0, 10, 22_840_000 ether);
        vestingData = VestingAllocation({
            vestingTypeId: 3,
            vestingDuration: 12,
            lockPeriod: 6,
            totalTokensAllocated: 22_840_000 ether,
            totalTGETokens: 0,
            totalTokensClaimed: 0,
            monthlyTokens: (22_840_000 ether * 10) / 100,
            investmentTimestamp: 1625979449, // TGE TIME
            vestor: _vestors[3],
            isVesting: true,
            isTGETokenClaimed: false
        });
        vestingDetails[_vestors[3]] = vestingData;
        totalVestingAmount += 22_840_000 ether;

        //MINING_REWARDS (20% of Total SHUB)
        vestingType[4] = VestingType(4, 12, 1, 0, 5, 40_000_000 ether);
        vestingData = VestingAllocation({
            vestingTypeId: 4,
            vestingDuration: 12,
            lockPeriod: 1,
            totalTokensAllocated: 40_000_000 ether,
            totalTGETokens: 0,
            totalTokensClaimed: 0,
            monthlyTokens: (40_000_000 ether * 5) / 100,
            investmentTimestamp: 1625979449, // TGE TIME
            vestor: _vestors[4],
            isVesting: true,
            isTGETokenClaimed: false
        });
        vestingDetails[_vestors[4]] = vestingData;
        totalVestingAmount += 40_000_000 ether;

        //EXCHANGE_LIQUIDITY (2% of Total SHUB)
        vestingType[5] = VestingType(5, 0, 0, 100, 0, 4_000_000 ether);
        vestingData = VestingAllocation({
            vestingTypeId: 5,
            vestingDuration: 0,
            lockPeriod: 0,
            totalTokensAllocated: 4_000_000 ether,
            totalTGETokens: 4_000_000 ether,
            totalTokensClaimed: 0,
            monthlyTokens: 0,
            investmentTimestamp: 1625979449, // TGE TIME
            vestor: _vestors[5],
            isVesting: true,
            isTGETokenClaimed: false
        });
        vestingDetails[_vestors[5]] = vestingData;
        totalVestingAmount += 4_000_000 ether;

        //ECO_SYSTEM (5% of Total SHUB)
        vestingType[6] = VestingType(6, 12, 6, 0, 10, 10_000_000 ether);
        vestingData = VestingAllocation({
            vestingTypeId: 6,
            vestingDuration: 12,
            lockPeriod: 6,
            totalTokensAllocated: 10_000_000 ether,
            totalTGETokens: 0,
            totalTokensClaimed: 0,
            monthlyTokens: (10_000_000 ether * 10) / 100,
            investmentTimestamp: 1625979449, // TGE TIME
            vestor: _vestors[6],
            isVesting: true,
            isTGETokenClaimed: false
        });
        vestingDetails[_vestors[6]] = vestingData;
        totalVestingAmount += 10_000_000 ether;

        uint256 ownerBalance = solhubTokenContract.balanceOf(owner());
        require(
            ownerBalance >= totalVestingAmount,
            "Insufficient owner balance"
        );
        solhubTokenContract.transferFrom(
            owner(),
            address(this),
            totalVestingAmount
        );
    }

    /**
     * @dev To get the invested tokens
     * @return - true if function executes successfully
     */
    //solhint-disable-next-line function-max-lines
    function claimVestingTokens()
        public
        onlyAfterTGE
        whenNotPaused
        returns (bool)
    {
        uint256 tokensToTransfer = 0;
        VestingAllocation memory vestingData = vestingDetails[msg.sender];
        //solhint-disable-next-line reason-string
        require(
            vestingData.vestingTypeId != 5,
            "Invalid investment index, no vesting for Exchange & Liquidity"
        );
        if (vestingData.isVesting) {
            // Get total amount of tokens claimed till date
            uint256 _totalTokensClaimed = totalTokensClaimed(msg.sender);
            // Get the total claimable token amount at the time of calling this function
            uint256 claimableTokens = calculateClaimableTokens(msg.sender);
            if (claimableTokens > 0) {
                if (
                    (_totalTokensClaimed + claimableTokens) <=
                    vestingData.totalTokensAllocated
                ) {
                    vestingData.totalTokensClaimed += claimableTokens;
                    if (
                        (_totalTokensClaimed + claimableTokens) ==
                        vestingData.totalTokensAllocated
                    ) {
                        vestingData.isVesting = false;
                    }
                    vestingDetails[msg.sender] = vestingData;
                    tokensToTransfer += claimableTokens;
                }
            }
            // Else it implies that user has already withdrawn for the current month
            // and should come next month and initiate vesting
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
        VestingAllocation memory vestingData = vestingDetails[msg.sender];
        if (vestingData.isVesting) {
            tgeAmount = vestingData.totalTGETokens;
            if (tgeAmount > 0 && !vestingData.isTGETokenClaimed) {
                vestingData.totalTokensClaimed += tgeAmount;
                vestingData.isTGETokenClaimed = true;
                vestingData.totalTGETokens = 0;
                vestingDetails[msg.sender] = vestingData;
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
     */
    function totalTokensClaimed(address _userAddresses)
        public
        view
        returns (uint256)
    {
        // Get Investment Details
        VestingAllocation memory vestingData = vestingDetails[_userAddresses];

        uint256 totalClaimedTokens = (vestingData.totalTokensClaimed);

        if (vestingData.isTGETokenClaimed) {
            totalClaimedTokens += vestingData.totalTGETokens;
        }

        return totalClaimedTokens;
    }

    /**
     * @dev To calculate total claimable tokens at any given point of time
     * @param _userAddress address of the User
     */
    //solhint-disable-next-line function-max-lines
    function calculateClaimableTokens(address _userAddress)
        internal
        view
        checkVestingStatus(_userAddress)
        returns (uint256)
    {
        // Get Vesting Details
        VestingAllocation memory vestingData = vestingDetails[_userAddress];

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
            totalMonthsElapsed > vestingData.lockPeriod,
            "Cannot claim in lock period"
        );

        uint256 _totalTokensClaimed = totalTokensClaimed(_userAddress);
        // If total duration of Vesting already crossed, return pending tokens to claimed
        if (totalMonthsElapsed > vestingData.vestingDuration) {
            actualClaimableAmount =
                vestingData.totalTokensAllocated -
                _totalTokensClaimed;
        } else {
            actualClaimableAmount =
                (totalMonthsElapsed * vestingData.monthlyTokens) -
                _totalTokensClaimed;
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
}
