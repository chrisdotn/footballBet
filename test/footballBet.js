contract('FootballBet', function(accounts) {
  it('create a new game for match 152250', function() {
    var bet = FootballBet.deployed();
    return bet.createGame.sendTransaction('152250', {'from':accounts[2], value:5000000000000000000}).then(function(balance) {
      assert.isAtLeast(web3.eth.getBalance(bet.address).valueOf(), 4900000000000000000, "There were not 5 ether in the contract.");
    });
  });
});
