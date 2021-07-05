async function main() {
    const NewSolhubInvestor = await ethers.getContractFactory("NewSolhubInvestor");
    const SolhubTokenAddress = "The Solhub ERC20 Token Address"
    console.log("Deploying NewSolhubInvestor...");
    const newSolhubInvestor = await upgrades.deployProxy(NewSolhubInvestor, [SolhubTokenAddress], { initializer: 'initialize' });
    console.log("NewSolhubInvestor deployed to:", newSolhubInvestor.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });