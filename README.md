# footballBet
A simple bet based on a Ethereum Smart Contract

This smart contract is used as example for an introduction to use oracles in Ethereum.

## Testing
Manual testing is available via these methods:

```
var bet = FootballBet.deployed();
var events = bet.allEvents(function(error, log){ if (!error) console.log(log.args); });
var accounts = ['0xb6460d8c1dac5e8e36f61e77ce92d8be6fa9a204', '0x089a6e9e19cc9e2109ef7d743336497acc078a8e', '0x6db9bbeab27b0645586b94c4cc850caaae0260d8', '0x78185129690ae1d7c1372d3d22e7935cfdd978cf', '0x08b94302f1e8de26b9b57fbd56f780c14d6e52a6', '0xe9b2c7b5335f41a9b60f0b9d0f2046204329c597', '0x165c2f89a3fc0912fca58938ed28ca76ba4f2132', '0xb92bd8719a53d45dc95e4c7d091a398e9e522a69', '0xc8af04d396b695ce61f85325f754c3bfe8aca006', '0xc5df1da6c8211978203a6a480a53580c49648e7c'];

bet.createGame.sendTransaction('152250', {'from':accounts[2], value:5000000000000000000});
bet.placeBet.sendTransaction('0', {'from':accounts[2], value:1000000000000000000});
bet.placeBet.sendTransaction('1', {'from':accounts[3], value:1000000000000000000});
bet.placeBet.sendTransaction('0', {'from':accounts[4], value:1000000000000000000});
bet.evaluate.sendTransaction({'from':accounts[2]});
bet.setWinners.sendTransaction({'from':accounts[2]});
bet.withdraw.sendTransaction({'from':accounts[3]});
```
