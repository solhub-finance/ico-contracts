const { expect } = require("chai");
const { ethers } = require("hardhat");


describe('NewVesting is [Ownable, Pausable]', () => {
    let accounts;
    let owner, nonOwner;
    let marketingInvestor, advisorInvestor, teamInvestor, reservesInvestor, miningRewardInvestor, exchangeLiquidityInvestor, ecoSystemInvestor;
    const initialSupply = ethers.BigNumber.from('1000000000000000000000000000') // 1 Billion SHUB Coins
    const allRoundInvestmentAmount = ethers.BigNumber.from('10000000000000000000000'); // 10K SHUB Coins

    let vestingConInstance;
    let solhubConInstance;
    let txObject;

    describe('NewVesting tests', () => {
        before(async () => {
            accounts = await ethers.getSigners();
            [owner, marketingInvestor, advisorInvestor, teamInvestor, reservesInvestor, miningRewardInvestor, exchangeLiquidityInvestor, ecoSystemInvestor, nonOwner] = accounts;


            const Solhub = await ethers.getContractFactory("Solhub");
            const NewVesting = await ethers.getContractFactory("NewVesting");
            solhubConInstance = await Solhub.deploy(initialSupply);
            vestingConInstance = await NewVesting.deploy();
            await vestingConInstance.initialize(solhubConInstance.address);
        });

        describe('reverts', () => {
            it('when initialize is called with SHUB token address = zero address', async () => {
                await expect(
                    vestingConInstance.initialize(ethers.constants.AddressZero)
                ).to.be.revertedWith("SHUB address is address zero.");
            })
        })


        describe('checks initialize invocation is successful', () => {
            it('should have Solhub Token Contract address to be set as expected', async () => {
                expect(await vestingConInstance.solhubTokenContract()).to.equal(solhubConInstance.address)
            })
        })

        describe('addInvestmentDetails', () => {
            before(async () => {
                await solhubConInstance.approve(vestingConInstance.address, ethers.constants.MaxUint256);
            })

            context('reverts', () => {
                it('reverts when addInvestmentDetails is invoked by non-owner', async () => {
                    await expect(
                        vestingConInstance.connect(nonOwner).addInvestmentDetails([marketingInvestor.address], [allRoundInvestmentAmount], 0)
                    ).to.be.revertedWith("Ownable: caller is not the owner")
                })
                it('reverts when investing index is invalid', async () => {
                    await expect(
                        vestingConInstance.addInvestmentDetails([marketingInvestor.address], [allRoundInvestmentAmount], 7)
                    ).to.be.revertedWith("Invalid Invested Index")
                })
                it('reverts when passed in params are not equal', async () => {
                    await expect(
                        vestingConInstance.addInvestmentDetails([marketingInvestor.address], [allRoundInvestmentAmount, 254], 0)
                    ).to.be.revertedWith("Unequal arrays passed")
                })
            })

            context('success', () => {
                it('should add 10K SHUB each for marketingInvestor for MARKETING round', async () => {
                    txObject = await vestingConInstance.addInvestmentDetails([marketingInvestor.address], [allRoundInvestmentAmount], 0)
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should check owner balance to be 9.9999e26 SHUB tokens', async () => {
                    expect(await solhubConInstance.balanceOf(owner.address)).to.equal('999990000000000000000000000')
                })
                it('should add 10K SHUB each for advisorInvestor for ADVISOR round', async () => {
                    txObject = await vestingConInstance.addInvestmentDetails([advisorInvestor.address], [allRoundInvestmentAmount], 1)
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should check owner balance to be 9.9998e26 SHUB tokens', async () => {
                    expect(await solhubConInstance.balanceOf(owner.address)).to.equal('999980000000000000000000000')
                })
                it('should add 10K SHUB each for teamInvestor for TEAM round', async () => {
                    txObject = await vestingConInstance.addInvestmentDetails([teamInvestor.address], [allRoundInvestmentAmount], 2)
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should check owner balance to be 9.9997e26 SHUB tokens', async () => {
                    expect(await solhubConInstance.balanceOf(owner.address)).to.equal('999970000000000000000000000')
                })
                it('should add 10K SHUB each for reservesInvestor for RESERVES round', async () => {
                    txObject = await vestingConInstance.addInvestmentDetails([reservesInvestor.address], [allRoundInvestmentAmount], 3)
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should check owner balance to be 9.9996e26 SHUB tokens', async () => {
                    expect(await solhubConInstance.balanceOf(owner.address)).to.equal('999960000000000000000000000')
                })
                it('should add 10K SHUB each for miningRewardInvestor for MINING_REWARD round', async () => {
                    txObject = await vestingConInstance.addInvestmentDetails([miningRewardInvestor.address], [allRoundInvestmentAmount], 4)
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should check owner balance to be 9.9995e26 SHUB tokens', async () => {
                    expect(await solhubConInstance.balanceOf(owner.address)).to.equal('999950000000000000000000000')
                })
                it('should add 10K SHUB each for exchangeLiquidityInvestor for EXCHANGE_LIQUIDITY round', async () => {
                    txObject = await vestingConInstance.addInvestmentDetails([exchangeLiquidityInvestor.address], [allRoundInvestmentAmount], 5)
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should check owner balance to be 9.9994e26 SHUB tokens', async () => {
                    expect(await solhubConInstance.balanceOf(owner.address)).to.equal('999940000000000000000000000')
                })
                it('should add 10K SHUB each for ecoSystemInvestor for ECO_SYSTEM round', async () => {
                    txObject = await vestingConInstance.addInvestmentDetails([ecoSystemInvestor.address], [allRoundInvestmentAmount], 6)
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should check owner balance to be 9.9993e26 SHUB tokens', async () => {
                    expect(await solhubConInstance.balanceOf(owner.address)).to.equal('999930000000000000000000000')
                })

                context('addUserInvestmentDetails', () => {
                    it('should revert when investor details are already added', async () => {
                        await expect(
                            vestingConInstance.addInvestmentDetails([marketingInvestor.address], [allRoundInvestmentAmount], 0)
                        ).to.be.revertedWith("Invested details already added")
                    })
                    it('should revert when investor address is zero address', async () => {
                        await expect(
                            vestingConInstance.addInvestmentDetails([ethers.constants.AddressZero], [initialSupply], 0)
                        ).to.be.revertedWith("Invalid Address")
                    })
                    it('should revert when ownerBalance < investmentAmount', async () => {
                        await expect(
                            vestingConInstance.addInvestmentDetails([nonOwner.address], [initialSupply], 0)
                        ).to.be.revertedWith("Insufficient owner balance")
                    })
                })
            })
        })

        describe('pauseContract', () => {
            it('reverts when pause is invoked by non-owner', async () => {
                await expect(
                    vestingConInstance.connect(nonOwner).pauseContract()
                ).to.be.revertedWith("Ownable: caller is not the owner")
            })
            it('should pause the contract successfully', async () => {
                txObject = await vestingConInstance.pauseContract()
                expect(txObject.confirmations).to.equal(1);
            })
            it('reverts when contract is already paused', async () => {
                await expect(
                    vestingConInstance.pauseContract()
                ).to.be.revertedWith("Pausable: paused")
            })
        })

        describe('unPauseContract', () => {
            it('reverts when unpause is invoked by non-owner', async () => {
                await expect(
                    vestingConInstance.connect(nonOwner).unPauseContract()
                ).to.be.revertedWith("Ownable: caller is not the owner")
            })
            it('should unpause the contract successfully', async () => {
                txObject = await vestingConInstance.unPauseContract()
                expect(txObject.confirmations).to.equal(1);
            })
            it('reverts when contract is already unpaused', async () => {
                await expect(
                    vestingConInstance.unPauseContract()
                ).to.be.revertedWith("Pausable: not paused")
            })
        })

        describe('claimTGETokens', () => {
            context('reverts', () => {
                it('when the contract is paused', async () => {
                    await vestingConInstance.pauseContract() // Pause Contract
                    await network.provider.send("evm_increaseTime", [259200]) // Increase time by 3 Days => 86400 * 3 => 259200
                    await network.provider.send("evm_mine")
                    await expect(
                        vestingConInstance.connect(marketingInvestor).claimTGETokens(0)
                    ).to.be.revertedWith("Pausable: paused")
                    await vestingConInstance.unPauseContract() // UnPause Contract
                })
                it('when investment index is invalid', async () => {
                    await expect(
                        vestingConInstance.connect(marketingInvestor).claimTGETokens(1)
                    ).to.be.revertedWith("Invalid investment index, no TGE")
                })
                it('when there are no tokens to transfer', async () => {
                    await expect(
                        vestingConInstance.connect(nonOwner).claimTGETokens(0)
                    ).to.be.revertedWith("No tokens to transfer")
                })
            })

            context('success', () => {
                let investorDetails;
                it('should claim TGE tokens for marketingInvestor', async () => {
                    txObject = await vestingConInstance.connect(marketingInvestor).claimTGETokens(0)
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should claim TGE tokens for exchangeLiquidityInvestor', async () => {
                    txObject = await vestingConInstance.connect(exchangeLiquidityInvestor).claimTGETokens(5)
                    expect(txObject.confirmations).to.equal(1);
                })
                it('should revert once TGE is already claimed', async () => {
                    await expect(vestingConInstance.connect(marketingInvestor).claimTGETokens(0)).to.be.revertedWith("No tokens to transfer");
                })

                context('verify after state of investors after claiming of TGE tokens', () => {
                    describe('MARKETING State for investors', () => {
                        before(async () => {
                            investorDetails = await vestingConInstance.investorsInvestmentDetails(marketingInvestor.address, 0);
                        })
                        it('should verify TGE tokens have been claimed for marketingInvestor', async () => {
                            expect(investorDetails.isTGETokenClaimed, true, "TGE not claimed")
                        })
                        it('should verify 500 total tokens have been claimed by marketingInvestor', async () => {
                            expect(investorDetails.totalTokensClaimed, 5e21, "Total tokens claimed do not match")
                        })
                        it('should verify total TGE tokens to be 0 after it has been claimed by marketingInvestor', async () => {
                            expect(investorDetails.totalTGETokens, 0, "Total tokens claimed do not match")
                        })
                    })
                    describe('EXCHANGE_LIQUIDITY State for investors', () => {
                        before(async () => {
                            investorDetails = await vestingConInstance.investorsInvestmentDetails(exchangeLiquidityInvestor.address, 5);
                        })
                        it('should verify TGE tokens have been claimed for exchangeLiquidityInvestor', async () => {
                            expect(investorDetails.isTGETokenClaimed, true, "TGE not claimed")
                        })
                        it('should verify 10K total tokens have been claimed by exchangeLiquidityInvestor', async () => {
                            expect(investorDetails.totalTokensClaimed, '10000000000000000000000', "Total tokens claimed do not match")
                        })
                        it('should verify total TGE tokens to be 0 after it has been claimed by exchangeLiquidityInvestor', async () => {
                            expect(investorDetails.totalTGETokens, 0, "Total tokens claimed do not match")
                        })
                    })
                })
            })
        })

        describe('totalTokensClaimed', () => {
            const marketingBalance = '500000000000000000000' // 500 SHUB
            const exchangeLiquidityBalance = '10000000000000000000000' // 10K SHUB
            context('MARKETING', () => {
                it('should verify total claimed tokens to equal 500 for marketingInvestor', async () => {
                    expect(await vestingConInstance.totalTokensClaimed(marketingInvestor.address, 0)).to.equal(marketingBalance)
                })
            })
            context('EXCHANGE_LIQUIDITY', () => {
                it('should verify total claimed tokens to equal 10K for exchangeLiquidityInvestor', async () => {
                    expect(await vestingConInstance.totalTokensClaimed(exchangeLiquidityInvestor.address, 5)).to.equal(exchangeLiquidityBalance);
                })
            })
        })

        describe('claimVestingTokens', () => {
            context('reverts', () => {
                it('when the contract is paused', async () => {
                    await vestingConInstance.pauseContract() // Pause Contract
                    await expect(
                        vestingConInstance.connect(marketingInvestor).claimVestingTokens(0)
                    ).to.be.revertedWith("Pausable: paused")
                    await vestingConInstance.unPauseContract() // UnPause Contract
                })
                it('when there are no tokens to transfer', async () => {
                    await expect(
                        vestingConInstance.connect(nonOwner).claimVestingTokens(0)
                    ).to.be.revertedWith("No tokens to transfer")
                })
            })

            context('success', () => {
                let investorDetails;
                context('Claim vesting tokens for MARKETING & MINING_REWARDS', () => {
                    before(async () => {
                        // Increase time by 31 Days so investors can claim vesting tokens
                        await network.provider.send("evm_increaseTime", [2678400]) // Increase time by 31 Days => 86400 * 31 => 2678400
                        await network.provider.send("evm_mine")
                    })
                    context('marketingInvestor', () => {
                        it('marketingInvestor initiates claimVestingTokens', async () => {
                            txObject = await vestingConInstance.connect(marketingInvestor).claimVestingTokens(0)
                            expect(txObject.confirmations).to.equal(1);
                        })
                        it('should check alreadyWithdrawn months to equal 1 for marketingInvestor', async () => {
                            expect(await vestingConInstance.alreadyWithdrawnMonths(marketingInvestor.address, 0)).to.equal(1);
                        })
                        it('should have withdrawn 1000 SHUB tokens for MARKETING round', async () => {
                            investorDetails = await vestingConInstance.investorsInvestmentDetails(marketingInvestor.address, 0)
                            expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x3635c9adc5dea00000');
                        })
                        it('should revert if claimVestingTokens is called again on the same month itself', async () => {
                            await expect(vestingConInstance.connect(marketingInvestor).claimVestingTokens(0)).to.be.revertedWith("No tokens to transfer")
                        })
                    })
                    context('miningRewardInvestor', () => {
                        it('miningRewardInvestor initiates claimVestingTokens', async () => {
                            txObject = await vestingConInstance.connect(miningRewardInvestor).claimVestingTokens(4)
                            expect(txObject.confirmations).to.equal(1);
                        })
                        it('should check alreadyWithdrawn months to equal 1 for miningRewardInvestor', async () => {
                            expect(await vestingConInstance.alreadyWithdrawnMonths(miningRewardInvestor.address, 4)).to.equal(1);
                        })
                        it('should have withdrawn 500 SHUB tokens for MINING_REWARDS round', async () => {
                            investorDetails = await vestingConInstance.investorsInvestmentDetails(miningRewardInvestor.address, 4)
                            expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x1b1ae4d6e2ef500000');
                        })
                        it('should revert if claimVestingTokens is called again on the same month itself', async () => {
                            await expect(vestingConInstance.connect(miningRewardInvestor).claimVestingTokens(4)).to.be.revertedWith("No tokens to transfer")
                        })
                    })
                })

                context('Claim vesting tokens for ADVISORS, RESERVES, ECO_SYSTEM', () => {
                    before(async () => {
                        // Increase time by 150 [5 Months] Days so investors can claim vesting tokens
                        await network.provider.send("evm_increaseTime", [12960000]) // Increase time by 150 Days => 86400 * 150 => 12960000
                        await network.provider.send("evm_mine")
                    })
                    context('advisorInvestor', () => {
                        it('advisorInvestor initiates claimVestingTokens', async () => {
                            txObject = await vestingConInstance.connect(advisorInvestor).claimVestingTokens(1)
                            expect(txObject.confirmations).to.equal(1);
                        })
                        it('should check alreadyWithdrawn months to equal 1 for advisorInvestor', async () => {
                            expect(await vestingConInstance.alreadyWithdrawnMonths(advisorInvestor.address, 1)).to.equal(6);
                        })
                        it('should have withdrawn 3000 SHUB tokens for ADVISORS round', async () => {
                            investorDetails = await vestingConInstance.investorsInvestmentDetails(advisorInvestor.address, 1)
                            expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0xa2a15d09519be00000');
                        })
                        it('should revert if claimVestingTokens is called again on the same month itself', async () => {
                            await expect(vestingConInstance.connect(advisorInvestor).claimVestingTokens(1)).to.be.revertedWith("No tokens to transfer")
                        })
                    })
                    context('reservesInvestor', () => {
                        it('reservesInvestor initiates claimVestingTokens', async () => {
                            txObject = await vestingConInstance.connect(reservesInvestor).claimVestingTokens(3)
                            expect(txObject.confirmations).to.equal(1);
                        })
                        it('should check alreadyWithdrawn months to equal 1 for reservesInvestor', async () => {
                            expect(await vestingConInstance.alreadyWithdrawnMonths(reservesInvestor.address, 3)).to.equal(6);
                        })
                        it('should have withdrawn 500 SHUB tokens for RESERVES round', async () => {
                            investorDetails = await vestingConInstance.investorsInvestmentDetails(reservesInvestor.address, 3)
                            expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x014542ba12a337c00000');
                        })
                        it('should revert if claimVestingTokens is called again on the same month itself', async () => {
                            await expect(vestingConInstance.connect(reservesInvestor).claimVestingTokens(3)).to.be.revertedWith("No tokens to transfer")
                        })
                    })
                    context('ecoSystemInvestor', () => {
                        it('ecoSystemInvestor initiates claimVestingTokens', async () => {
                            txObject = await vestingConInstance.connect(ecoSystemInvestor).claimVestingTokens(6)
                            expect(txObject.confirmations).to.equal(1);
                        })
                        it('should check alreadyWithdrawn months to equal 1 for ecoSystemInvestor', async () => {
                            expect(await vestingConInstance.alreadyWithdrawnMonths(ecoSystemInvestor.address, 6)).to.equal(6);
                        })
                        it('should have withdrawn 500 SHUB tokens for ECO_SYSTEM round', async () => {
                            investorDetails = await vestingConInstance.investorsInvestmentDetails(ecoSystemInvestor.address, 6)
                            expect(investorDetails.totalTokensClaimed.toHexString()).to.equal('0x014542ba12a337c00000');
                        })
                        it('should revert if claimVestingTokens is called again on the same month itself', async () => {
                            await expect(vestingConInstance.connect(ecoSystemInvestor).claimVestingTokens(6)).to.be.revertedWith("No tokens to transfer")
                        })
                    })
                })
            })
        })
    })
})