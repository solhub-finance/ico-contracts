const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * Note: If numbers are not casted using ethers.BigNumber.from and used directly that results in below error:
 * Error: overflow (
 *       fault="overflow", operation="BigNumber.from", value=3e+21, code=NUMERIC_FAULT, version=bignumber/5.3.0
 *       )
 * Thus, for Bib Numbers, the hex-encoded mechaninsm is used
 */
describe('Solhub is [ERC20, Ownable]', () => {
    let accounts;
    let owner;
    let acc1;
    let acc2;

    const initialSupply = ethers.BigNumber.from('1000000000000000000000000000') // 1 Billion SHBT Coins
    const actualTokenDecimals = 18;
    const updatedTokenDecimals = 8;

    let solhubConInstance;
    let txObject;

    context('Solhub tests', () => {
        before(async () => {
            accounts = await ethers.getSigners();
            [owner, acc1, acc2] = accounts;
            const Solhub = await ethers.getContractFactory("Solhub");
            solhubConInstance = await Solhub.deploy(initialSupply, actualTokenDecimals)
        });

        context('checks constructor invocation is successful', () => {
            it('should have token name to be `SolhubCoin`', async () => {
                expect(await solhubConInstance.name()).to.equal('SolhubCoin')
            })
            it('should have token symbol to be `SHBT`', async () => {
                expect(await solhubConInstance.symbol()).to.equal('SHBT')
            })
            it('should have token tokenDecimals to be 18', async () => {
                expect(await solhubConInstance.decimals()).to.equal(actualTokenDecimals)
            })
            it('should verify totalSupply is 1 Billion SHBT', async () => {
                expect(await solhubConInstance.totalSupply()).to.equal(initialSupply)
            })
        })


        context('burn', () => {
            const transferAmount = ethers.BigNumber.from('3000000000000000000000'); // 3000 SHBT
            const burnAmount = ethers.BigNumber.from('1000000000000000000000'); // 1000 SHBT
            const excessAmount = ethers.BigNumber.from('4000000000000000000000'); // 4000 SHBT
            const balanceAfterBurn = ethers.BigNumber.from('2000000000000000000000'); // 2000 SHBT
            before(async () => {
                // Transfer 3000 SHBT to acc1 then burn 1000 SHBT from acc1
                await solhubConInstance.transfer(acc1.address, transferAmount);
            })
            it('reverts when burn amount is greater than token balance', async () => {
                await expect(
                    solhubConInstance.connect(acc1).burn(excessAmount)
                ).to.be.revertedWith("Cannot burn more than balance")
            })
            it("before burn account balance is 3000 SHBT", async () => {
                expect(await solhubConInstance.balanceOf(acc1.address)).to.equal(transferAmount)
            })
            it('burns 1000 SHBT coins of acc1', async () => {
                txObject = await solhubConInstance.connect(acc1).burn(burnAmount)
                expect(txObject.confirmations).to.equal(1);
            })
            it("after burn acc1 balance is 2000 SHBT coins", async () => {
                expect(await solhubConInstance.balanceOf(acc1.address)).to.equal(balanceAfterBurn);
            })
        })

        context('mint', () => {
            const mintAmount = ethers.BigNumber.from('3000000000000000000000'); // 3000 SHBT
            it('reverts when mint is invoked by non-owner', async () => {
                await expect(
                    solhubConInstance.connect(acc2).mint(acc2.address, mintAmount)
                ).to.be.revertedWith("Ownable: caller is not the owner")
            })
            it("before mint acc2 balance is 0 SHBT", async () => {
                expect(await solhubConInstance.balanceOf(acc2.address)).to.equal(0)
            })
            it('should mint 3000 SHBT coins for acc2', async () => {
                txObject = await solhubConInstance.mint(acc2.address, mintAmount)
                expect(txObject.confirmations).to.equal(1);
            })
            it("after mint acc2 balance is 3000 SHBT coins", async () => {
                expect(await solhubConInstance.balanceOf(acc2.address)).to.equal(mintAmount);
            })
        })

        context('withdrawAll', () => {
            const oneEth = ethers.constants.WeiPerEther;
            it('sends 1 ether to the contract', async () => {
                txObject = await owner.sendTransaction({
                    to: solhubConInstance.address,
                    value: oneEth
                });
                expect(txObject.confirmations).to.equal(1);
            })

            it('should verify contract balance to be 1 Eth', async () => {
                expect(await ethers.provider.getBalance(solhubConInstance.address)).to.equal(oneEth)
            })

            it('should withdraw 1 Eth from the contract', async () => {
                txObject = await solhubConInstance.withdrawAll()
                expect(txObject.confirmations).to.equal(1);
            })

            it('after withdraw should verify contract balance to be 0 Eth', async () => {
                expect(await ethers.provider.getBalance(solhubConInstance.address)).to.equal(0)
            })
        })
    })
})