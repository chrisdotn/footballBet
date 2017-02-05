module.exports = function(deployer) {
    deployer.deploy(usingOraclize);
    deployer.deploy(FootballBet);
    deployer.autolink();
};
