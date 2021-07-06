const { expect } = require("chai");
const { ethers } = require("hardhat");


describe.only('NewSolhubInvestor is [Ownable, Pausable]', () => {
    let accounts;
    let owner, nonOwner;
    let investor1, investor2, investor3;
    let userAddresses = [];
    const initialSupply = ethers.BigNumber.from('1000000000000000000000000000') // 1 Billion SHUB Coins
    const seedRoundInvestmentAmount = ethers.BigNumber.from('10000000000000000000000'); // 10K SHUB Coins
    const strategicRoundInvestmentAmount = ethers.BigNumber.from('20000000000000000000000'); // 20K SHUB Coins
    const privateRoundInvestmentAmount = ethers.BigNumber.from('30000000000000000000000'); // 30K SHUB Coins

    let investorConInstance;
    let solhubConInstance;
    let txObject;

    describe('NewSolhubInvestor tests', () => {
        before(async () => {
            accounts = await ethers.getSigners();
            [owner, investor1, investor2, investor3, nonOwner] = accounts;

            userAddresses.push(investor1.address)
            userAddresses.push(investor2.address)
            userAddresses.push(investor3.address)

            const Solhub = await ethers.getContractFactory("Solhub");
            const NewSolhubInvestor = await ethers.getContractFactory("NewSolhubInvestor");
            solhubConInstance = await Solhub.deploy(initialSupply);
            investorConInstance = await NewSolhubInvestor.deploy();
            await investorConInstance.initialize(solhubConInstance.address);
        });

        describe('reverts', () => {
            it('when initialize is called with SHUB token address = zero address', async () => {
                await expect(
                    investorConInstance.initialize(ethers.constants.AddressZero)
                ).to.be.revertedWith("SHUB address is address zero.");
            })
        })


        describe('checks initialize invocation is successful', () => {
            it('should have Solhub Token Contract address to be set as expected', async () => {
                expect(await investorConInstance.solhubTokenContract()).to.equal(solhubConInstance.address)
            })
        })

        describe('addInvestmentDetails', () => {
            const seedInvestedAmounts = [seedRoundInvestmentAmount, seedRoundInvestmentAmount, seedRoundInvestmentAmount]
            const strategicInvestedAmounts = [strategicRoundInvestmentAmount, strategicRoundInvestmentAmount, strategicRoundInvestmentAmount]
            const privateInvestedAmounts = [privateRoundInvestmentAmount, privateRoundInvestmentAmount, privateRoundInvestmentAmount]

            before(async () => {
                await solhubConInstance.approve(investorConInstance.address, ethers.constants.MaxUint256);
            })
            context('reverts', () => {
                it('reverts when addInvestmentDetails is invoked by non-owner', async () => {
                    await expect(
                        investorConInstance.connect(nonOwner).addInvestmentDetails(userAddresses, seedInvestedAmounts, 0)
                    ).to.be.revertedWith("Ownable: caller is not the owner")
                })
                it('reverts when investing index is invalid', async () => {
                    await expect(
                        investorConInstance.addInvestmentDetails(userAddresses, seedInvestedAmounts, 3)
                    ).to.be.revertedWith("Invalid Invested Index")
                })
                it('reverts when passed in params are not equal', async () => {
                    await expect(
                        investorConInstance.addInvestmentDetails(userAddresses, [1, 2], 0)
                    ).to.be.revertedWith("Unequal arrays passed")
                })
            })

            context('success', () => {
                const ownerBalanceAfterSeedInvestment = '999970000000000000000000000' //initialSupply - (seedRoundInvestmentAmount * 3) => 9.9997e26 SHUB
                const ownerBalanceAfterStrategicInvestment = '999910000000000000000000000' // ownerBalanceAfterSeedInvestment - (strategicRoundInvestmentAmount * 3) => 9.9991e26 SHUB
                const ownerBalanceAfterPrivateInvestment = '999820000000000000000000000' // ownerBalanceAfterStrategicInvestment - (privateRoundInvestmentAmount * 3) => 9.9982e26 SHUB

                it('should add 10K SHUB each for Investor1, Investor2 & Investor3 for SEED round', async () => {
                    txObject = await investorConInstance.addInvestmentDetails(userAddresses, seedInvestedAmounts, 0)
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should check owner balance to be 9.997e26 SHUB tokens', async () => {
                    expect(await solhubConInstance.balanceOf(owner.address)).to.equal(ownerBalanceAfterSeedInvestment)
                })
                it('should add 20K SHUB for Investor1, Investor2 & Investor3 each for STRATEGIC round', async () => {
                    txObject = await investorConInstance.addInvestmentDetails(userAddresses, strategicInvestedAmounts, 1)
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should check owner balance to be 9.9991e26 SHUB tokens', async () => {
                    expect(await solhubConInstance.balanceOf(owner.address)).to.equal(ownerBalanceAfterStrategicInvestment)
                })
                it('should add 30K SHUB for Investor1, Investor2 & Investor3 each for PRIVATE round', async () => {
                    txObject = await investorConInstance.addInvestmentDetails(userAddresses, privateInvestedAmounts, 2)
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should check owner balance to be 9.9982e26 SHUB tokens', async () => {
                    expect(await solhubConInstance.balanceOf(owner.address)).to.equal(ownerBalanceAfterPrivateInvestment)
                })
                it('should check investor contract balance to be 1.8e23 SHUB tokens', async () => {
                    expect(await solhubConInstance.balanceOf(investorConInstance.address)).to.equal('180000000000000000000000')
                })
                context('addUserInvestmentDetails', () => {
                    it('should revert when investor details are already added', async () => {
                        await expect(
                            investorConInstance.addInvestmentDetails([userAddresses[0]], [initialSupply], 0)
                        ).to.be.revertedWith("Invested details already added")
                    })
                    it('should revert when investor address is zero address', async () => {
                        await expect(
                            investorConInstance.addInvestmentDetails([ethers.constants.AddressZero], [initialSupply], 0)
                        ).to.be.revertedWith("Invalid Address")
                    })
                    it('should revert when ownerBalance < investmentAmount', async () => {
                        await expect(
                            investorConInstance.addInvestmentDetails([nonOwner.address], [initialSupply], 0)
                        ).to.be.revertedWith("Insufficient owner balance")
                    })
                })
            })
        })

        describe('pauseContract', () => {
            it('reverts when pause is invoked by non-owner', async () => {
                await expect(
                    investorConInstance.connect(nonOwner).pauseContract()
                ).to.be.revertedWith("Ownable: caller is not the owner")
            })
            it('should pause the contract successfully', async () => {
                txObject = await investorConInstance.pauseContract()
                expect(txObject.confirmations).to.equal(1);
            })
            it('reverts when contract is already paused', async () => {
                await expect(
                    investorConInstance.pauseContract()
                ).to.be.revertedWith("Pausable: paused")
            })
        })

        describe('unPauseContract', () => {
            it('reverts when unpause is invoked by non-owner', async () => {
                await expect(
                    investorConInstance.connect(nonOwner).unPauseContract()
                ).to.be.revertedWith("Ownable: caller is not the owner")
            })
            it('should unpause the contract successfully', async () => {
                txObject = await investorConInstance.unPauseContract()
                expect(txObject.confirmations).to.equal(1);
            })
            it('reverts when contract is already unpaused', async () => {
                await expect(
                    investorConInstance.unPauseContract()
                ).to.be.revertedWith("Pausable: not paused")
            })
        })

        describe('claimTGETokens', () => {
            context('reverts', () => {
                it('when TGE is not started', async () => {
                    await expect(
                        investorConInstance.connect(investor1).claimTGETokens()
                    ).to.be.revertedWith("TGE not yet started")
                })
                it('when the contract is paused', async () => {
                    await investorConInstance.pauseContract() // Pause Contract
                    await network.provider.send("evm_increaseTime", [259200]) // Increase time by 3 Days => 86400 * 3 => 259200
                    await network.provider.send("evm_mine")
                    await expect(
                        investorConInstance.connect(investor1).claimTGETokens()
                    ).to.be.revertedWith("Pausable: paused")
                    await investorConInstance.unPauseContract() // UnPause Contract
                })
                it('when there are no tokens to transfer', async () => {
                    await expect(
                        investorConInstance.connect(nonOwner).claimTGETokens()
                    ).to.be.revertedWith("No tokens to transfer")
                })
            })

            context('success', () => {
                let investorDetails;
                it('should claim TGE tokens for investor1', async () => {
                    txObject = await investorConInstance.connect(investor1).claimTGETokens()
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should claim TGE tokens for investor2', async () => {
                    txObject = await investorConInstance.connect(investor2).claimTGETokens()
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should claim TGE tokens for investor3', async () => {
                    txObject = await investorConInstance.connect(investor3).claimTGETokens()
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should verify after claim of TGE tokens investor contract balance to equal 1.665e23', async () => {
                    expect(await solhubConInstance.balanceOf(investorConInstance.address)).to.equal('166500000000000000000000')
                })
                it('should revert once TGE is already claimed', async () => {
                    await expect(investorConInstance.connect(investor3).claimTGETokens()).to.be.revertedWith("No tokens to transfer");
                })
                context('verify after state of investors after claiming of TGE tokens', () => {
                    describe('SEED State for investors', () => {
                        describe('investor1 state for SEED investment', () => {
                            before(async () => {
                                investorDetails = await investorConInstance.investorsInvestmentDetails(investor1.address, 0);
                            })
                            it('should verify TGE tokens have been claimed for investor1', async () => {
                                expect(investorDetails.isTGETokenClaimed, true, "TGE not claimed")
                            })
                            it('should verify 500 total tokens have been claimed by investor1', async () => {
                                expect(investorDetails.totalTokensClaimed, 5e21, "Total tokens claimed do not match")
                            })
                            it('should verify total TGE tokens to be 0 after it has been claimed by investor1', async () => {
                                expect(investorDetails.totalTGETokens, 0, "Total tokens claimed do not match")
                            })
                        })

                        describe('investor2 state for SEED investment', () => {
                            before(async () => {
                                investorDetails = await investorConInstance.investorsInvestmentDetails(investor2.address, 0);
                            })
                            it('should verify TGE tokens have been claimed for investor2', async () => {
                                expect(investorDetails.isTGETokenClaimed, true, "TGE not claimed")
                            })
                            it('should verify 500 total tokens have been claimed by investor2', async () => {
                                expect(investorDetails.totalTokensClaimed, 5e21, "Total tokens claimed do not match")
                            })
                            it('should verify total TGE tokens to be 0 after it has been claimed by investor2', async () => {
                                expect(investorDetails.totalTGETokens, 0, "Total tokens claimed do not match")
                            })
                        })

                        describe('investor3 state for SEED investment', () => {
                            before(async () => {
                                investorDetails = await investorConInstance.investorsInvestmentDetails(investor3.address, 0);
                            })
                            it('should verify TGE tokens have been claimed for investor3', async () => {
                                expect(investorDetails.isTGETokenClaimed, true, "TGE not claimed")
                            })
                            it('should verify 500 total tokens have been claimed by investor3', async () => {
                                expect(investorDetails.totalTokensClaimed, 5e21, "Total tokens claimed do not match")
                            })
                            it('should verify total TGE tokens to be 0 after it has been claimed by investor3', async () => {
                                expect(investorDetails.totalTGETokens, 0, "Total tokens claimed do not match")
                            })
                        })
                    })

                    describe('STRATEGIC State for investors', () => {
                        describe('investor1 state for STRATEGIC investment', () => {
                            before(async () => {
                                investorDetails = await investorConInstance.investorsInvestmentDetails(investor1.address, 1);
                            })
                            it('should verify TGE tokens have been claimed for investor1', async () => {
                                expect(investorDetails.isTGETokenClaimed, true, "TGE not claimed")
                            })
                            it('should verify 1000 total tokens have been claimed by investor1', async () => {
                                expect(investorDetails.totalTokensClaimed, 1e22, "Total tokens claimed do not match")
                            })
                            it('should verify total TGE tokens to be 0 after it has been claimed by investor1', async () => {
                                expect(investorDetails.totalTGETokens, 0, "Total tokens claimed do not match")
                            })
                        })

                        describe('investor2 state for STRATEGIC investment', () => {
                            before(async () => {
                                investorDetails = await investorConInstance.investorsInvestmentDetails(investor2.address, 1);
                            })
                            it('should verify TGE tokens have been claimed for investor2', async () => {
                                expect(investorDetails.isTGETokenClaimed, true, "TGE not claimed")
                            })
                            it('should verify 1000 total tokens have been claimed by investor2', async () => {
                                expect(investorDetails.totalTokensClaimed, 1e22, "Total tokens claimed do not match")
                            })
                            it('should verify total TGE tokens to be 0 after it has been claimed by investor2', async () => {
                                expect(investorDetails.totalTGETokens, 0, "Total tokens claimed do not match")
                            })
                        })

                        describe('investor3 state for STRATEGIC investment', () => {
                            before(async () => {
                                investorDetails = await investorConInstance.investorsInvestmentDetails(investor3.address, 1);
                            })
                            it('should verify TGE tokens have been claimed for investor3', async () => {
                                expect(investorDetails.isTGETokenClaimed, true, "TGE not claimed")
                            })
                            it('should verify 1000 total tokens have been claimed by investor3', async () => {
                                expect(investorDetails.totalTokensClaimed, 1e22, "Total tokens claimed do not match")
                            })
                            it('should verify total TGE tokens to be 0 after it has been claimed by investor3', async () => {
                                expect(investorDetails.totalTGETokens, 0, "Total tokens claimed do not match")
                            })
                        })
                    })

                    describe('PRIVATE State for investors', () => {
                        describe('investor1 state for PRIVATE investment', () => {
                            before(async () => {
                                investorDetails = await investorConInstance.investorsInvestmentDetails(investor1.address, 2);
                            })
                            it('should verify TGE tokens have been claimed for investor1', async () => {
                                expect(investorDetails.isTGETokenClaimed, true, "TGE not claimed")
                            })
                            it('should verify 3000 total tokens have been claimed by investor1', async () => {
                                expect(investorDetails.totalTokensClaimed, 3e22, "Total tokens claimed do not match")
                            })
                            it('should verify total TGE tokens to be 0 after it has been claimed by investor1', async () => {
                                expect(investorDetails.totalTGETokens, 0, "Total tokens claimed do not match")
                            })
                        })

                        describe('investor2 state for PRIVATE investment', () => {
                            before(async () => {
                                investorDetails = await investorConInstance.investorsInvestmentDetails(investor2.address, 2);
                            })
                            it('should verify TGE tokens have been claimed for investor2', async () => {
                                expect(investorDetails.isTGETokenClaimed, true, "TGE not claimed")
                            })
                            it('should verify 3000 total tokens have been claimed by investor2', async () => {
                                expect(investorDetails.totalTokensClaimed, 3e22, "Total tokens claimed do not match")
                            })
                            it('should verify total TGE tokens to be 0 after it has been claimed by investor2', async () => {
                                expect(investorDetails.totalTGETokens, 0, "Total tokens claimed do not match")
                            })
                        })

                        describe('investor3 state for PRIVATE investment', () => {
                            before(async () => {
                                investorDetails = await investorConInstance.investorsInvestmentDetails(investor3.address, 2);
                            })
                            it('should verify TGE tokens have been claimed for investor3', async () => {
                                expect(investorDetails.isTGETokenClaimed, true, "TGE not claimed")
                            })
                            it('should verify 3000 total tokens have been claimed by investor3', async () => {
                                expect(investorDetails.totalTokensClaimed, 3e22, "Total tokens claimed do not match")
                            })
                            it('should verify total TGE tokens to be 0 after it has been claimed by investor3', async () => {
                                expect(investorDetails.totalTGETokens, 0, "Total tokens claimed do not match")
                            })
                        })
                    })
                })
            })
        })

        describe('totalTokensClaimed', () => {
            const seedBalance = '500000000000000000000' // 500 SHUB
            const strategicBalance = '1000000000000000000000' // 1000 SHUB
            const privateBalance = '3000000000000000000000' // 3000 SHUB
            context('SEED', () => {
                it('should verify total claimed tokens to equal 500 for investor1', async () => {
                    expect(await investorConInstance.totalTokensClaimed(investor1.address, 0)).to.equal(seedBalance)
                })
                it('should verify total claimed tokens to equal 500 for investor2', async () => {
                    expect(await investorConInstance.totalTokensClaimed(investor2.address, 0)).to.equal(seedBalance)
                })
                it('should verify total claimed tokens to equal 500 for investor3', async () => {
                    expect(await investorConInstance.totalTokensClaimed(investor3.address, 0)).to.equal(seedBalance)
                })
            })
            context('STRATEGIC', () => {
                it('should verify total claimed tokens to equal 500 for investor1', async () => {
                    expect(await investorConInstance.totalTokensClaimed(investor1.address, 1)).to.equal(strategicBalance);
                })
                it('should verify total claimed tokens to equal 500 for investor2', async () => {
                    expect(await investorConInstance.totalTokensClaimed(investor2.address, 1)).to.equal(strategicBalance);
                })
                it('should verify total claimed tokens to equal 500 for investor3', async () => {
                    expect(await investorConInstance.totalTokensClaimed(investor3.address, 1)).to.equal(strategicBalance);
                })
            })
            context('PRIVATE', () => {
                it('should verify total claimed tokens to equal 500 for investor1', async () => {
                    expect(await investorConInstance.totalTokensClaimed(investor1.address, 2)).to.equal(privateBalance);
                })
                it('should verify total claimed tokens to equal 500 for investor2', async () => {
                    expect(await investorConInstance.totalTokensClaimed(investor2.address, 2)).to.equal(privateBalance);
                })
                it('should verify total claimed tokens to equal 500 for investor3', async () => {
                    expect(await investorConInstance.totalTokensClaimed(investor3.address, 2)).to.equal(privateBalance);
                })
            })

        })

        describe('claimVestingTokens', () => {
            context('reverts', () => {
                it('when the contract is paused', async () => {
                    await investorConInstance.pauseContract() // Pause Contract
                    await expect(
                        investorConInstance.connect(investor1).claimVestingTokens()
                    ).to.be.revertedWith("Pausable: paused")
                    await investorConInstance.unPauseContract() // UnPause Contract
                })
                it('when there are no tokens to transfer', async () => {
                    await expect(
                        investorConInstance.connect(nonOwner).claimVestingTokens()
                    ).to.be.revertedWith("No tokens to transfer")
                })
                it('when trying to claim within lock period', async () => {
                    await expect(
                        investorConInstance.connect(investor1).claimVestingTokens()
                    ).to.be.revertedWith("Cannot claim in lock period")
                })
            })

            context('success', () => {
                /*
                const seedRoundDailyTokens = 27397260273972600000;
                const strategicRoundDailyTokens = 54794520547945200000;
                const privateRoundDailyTokens = 82191780821917810000;
                const seedRoundTokensClaimed = '0x' + (seedRoundDailyTokens * 34 + 5e20).toString(16);
                const strategicRoundTokensClaimed = '0x' + (strategicRoundDailyTokens * 34 + 1e21).toString(16);
                const privateRoundTokensClaimed = '0x' + (privateRoundDailyTokens * 34 + 3e21).toString(16);
                */
                let investorDetails;
                before(async () => {
                    // Increase time by 30 Days so investors can claim vesting tokens
                    await network.provider.send("evm_increaseTime", [2678400]) // Increase time by 31 Days => 86400 * 31 => 2678400
                    await network.provider.send("evm_mine")
                })

                context('Investor1', () => {
                    it('investor1 initiates claimVestingTokens', async () => {
                        txObject = await investorConInstance.connect(investor1).claimVestingTokens()
                        expect(txObject.confirmations).to.equal(1);
                    })

                    it('should check alreadyWithdrawn days to equal 34 for investor1', async () => {
                        expect(await investorConInstance.alreadyWithdrawnDays(investor1.address, 1)).to.equal(34);
                    })

                    it('should have withdrawn seedRoundDailyTokens * 34 SHUB tokens for SEED round', async () => {
                        investorDetails = await investorConInstance.investorsInvestmentDetails(investor1.address, 0)
                        expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x4d9a25f700f34abd46');
                    })

                    it('should have withdrawn strategicRoundDailyTokens * 34 SHUB tokens for STRATEGIC round', async () => {
                        investorDetails = await investorConInstance.investorsInvestmentDetails(investor1.address, 1)
                        expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x9b344bee01e6957aae');
                    })

                    it('should have withdrawn privateRoundDailyTokens * 34 SHUB tokens for PRIVATE round', async () => {
                        investorDetails = await investorConInstance.investorsInvestmentDetails(investor1.address, 2)
                        expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x013a1f2069aba7d03816');
                    })

                    it('should revert if claimVestingTokens is called again on the same day itself', async () => {
                        await expect(investorConInstance.connect(investor1).claimVestingTokens()).to.be.revertedWith("No tokens to transfer")
                    })
                })

                context('Investor2', () => {
                    it('investor2 initiates claimVestingTokens', async () => {
                        txObject = await investorConInstance.connect(investor2).claimVestingTokens()
                        expect(txObject.confirmations).to.equal(1);
                    })

                    it('should check alreadyWithdrawn days to equal 34 for investor1', async () => {
                        expect(await investorConInstance.alreadyWithdrawnDays(investor2.address, 1)).to.equal(34);
                    })

                    it('should have withdrawn seedRoundDailyTokens * 34 SHUB tokens for SEED round', async () => {
                        investorDetails = await investorConInstance.investorsInvestmentDetails(investor2.address, 0)
                        expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x4d9a25f700f34abd46');
                    })

                    it('should have withdrawn strategicRoundDailyTokens * 34 SHUB tokens for STRATEGIC round', async () => {
                        investorDetails = await investorConInstance.investorsInvestmentDetails(investor2.address, 1)
                        expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x9b344bee01e6957aae');
                    })

                    it('should have withdrawn privateRoundDailyTokens * 34 SHUB tokens for PRIVATE round', async () => {
                        investorDetails = await investorConInstance.investorsInvestmentDetails(investor2.address, 2)
                        expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x013a1f2069aba7d03816');
                    })

                    it('should revert if claimVestingTokens is called again on the same day itself', async () => {
                        await expect(investorConInstance.connect(investor2).claimVestingTokens()).to.be.revertedWith("No tokens to transfer")
                    })
                })

                context('Investor3', () => {
                    it('investor3 initiates claimVestingTokens', async () => {
                        txObject = await investorConInstance.connect(investor3).claimVestingTokens()
                        expect(txObject.confirmations).to.equal(1);
                    })

                    it('should check alreadyWithdrawn days to equal 34 for investor1', async () => {
                        expect(await investorConInstance.alreadyWithdrawnDays(investor3.address, 1)).to.equal(34);
                    })

                    it('should have withdrawn seedRoundDailyTokens * 34 SHUB tokens for SEED round', async () => {
                        investorDetails = await investorConInstance.investorsInvestmentDetails(investor3.address, 0)
                        expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x4d9a25f700f34abd46');
                    })

                    it('should have withdrawn strategicRoundDailyTokens * 34 SHUB tokens for STRATEGIC round', async () => {
                        investorDetails = await investorConInstance.investorsInvestmentDetails(investor3.address, 1)
                        expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x9b344bee01e6957aae');
                    })

                    it('should have withdrawn privateRoundDailyTokens * 34 SHUB tokens for PRIVATE round', async () => {
                        investorDetails = await investorConInstance.investorsInvestmentDetails(investor3.address, 2)
                        expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x013a1f2069aba7d03816');
                    })

                    it('should revert if claimVestingTokens is called again on the same day itself', async () => {
                        await expect(investorConInstance.connect(investor3).claimVestingTokens()).to.be.revertedWith("No tokens to transfer")
                    })
                })

                context('contract SHUB balance', () => {
                    /**
                     * For SEED round investment = 30000 SHUB
                     * For STRATEGIC round investment = 60000 SHUB
                     * For PRIVATE round investment = 90000 SHUB
                     * Thus, total SHUB in the contract = 180000
                     * TGE tokens of SEED, STRATEGIC, PRIVATE = 4500 for investor1, investor2, investor3
                     * TGE was claimed above, thus contract balance = 180000 - (4500 * 3) => 166500
                     * During claimVestingTokens each investor received: 5589.04109589041 SHUB Tokens
                     * Thus, totalVesting = 5589.04109589041 * 3 => 16767.12328767123 SHUB Tokens
                     * This makes contractBalance => 166500 - 16767.12328767123 => 149732.87671232875
                     * On converting (149732.87671232875 * 1e18) to hex we get '0x1fb509174315036eafe2'
                     * 
                     * The 1e18 has been used in the last step to make sure calculations are easier to understand
                     * It is 1e18 because the token decimals are 18
                     */
                    it('contract should have balance "0x1fb509174315036eafe2" SHUB tokens', async () => {
                        expect(await solhubConInstance.balanceOf(investorConInstance.address)).to.equal('0x1fb509174315036eafe2');
                    })
                })

            })
        })


    })
})