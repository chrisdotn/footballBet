pragma solidity ^0.4.2;

import './lib/usingOraclize.sol';
import './lib/strings.sol';
import './lib/JsmnSol.sol';

contract FootballBet is usingOraclize {
    using strings for *;

    string constant JSON_FIXTURE = '.fixture';
    string constant JSON_RESULT = '.fixture.result';
    string constant JSON_STATUS = 'status';
    string constant JSON_HOME_TEAM = 'homeTeamName';
    string constant JSON_AWAY_TEAM = 'awayTeamName';
    string constant JSON_HOME_GOALS = 'goalsHomeTeam';
    string constant JSON_AWAY_GOALS = 'goalsAwayTeam';

    enum Result { HOMETEAMWIN, AWAYTEAMWIN, DRAW, PENDING, UNKNOWN }

    struct Game {
        string gameId;
        string date;
        string status;
        string homeTeam;
        string awayTeam;
        uint homeTeamGoals;
        uint awayTeamGoals;
        Result result;
        uint receivedGoalMsgs;
    }

    struct Bet {
        uint stake;
        uint win;
        address sender;
    }

    struct Request {
        bool initialized;
        bool processed;
        string key;
    }

    mapping(uint8 => Bet[]) bets;
    mapping(uint8 => uint) betSums;

    mapping(address => uint) pendingWithdrawals;

    Game game;

    mapping (bytes32 => Request) requests;

    event Info(string message);
    event BetEvent(uint stake, uint win, address sender);

    function FootballBet() {
        OAR = OraclizeAddrResolverI(0xfE736E927c7233938c70672c5416B09bCCA348Cd);
    }

    function generateUrl(string base, string id, string filter, string jsonPath) constant returns (string) {
        strings.slice[] memory parts = new strings.slice[](7);
        parts[0] = 'json('.toSlice();
        parts[1] = base.toSlice();
        parts[2] = id.toSlice();
        parts[3] = filter.toSlice();
        parts[4] = ')'.toSlice();
        parts[5] = jsonPath.toSlice();
        return ''.toSlice().join(parts);
    }

    function queryFootballData(string gameId, string key, uint gas) public {
        if (oraclize_getPrice('URL') > this.balance) {
            Info('Oraclize query was NOT sent, please add some ETH to cover for the query fee');
        } else {
            string memory url = generateUrl('https://api.football-data.org/v1/fixtures/', gameId, '?head2head=0', key);
            oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
            bytes32 requestId = oraclize_query('URL', url, gas);
            requests[requestId] = Request(true, false, key);
            Info('Oraclize query was sent, standing by for the answer..');
        }
    }

    function createGame(string gameId) public payable {
        game = Game(gameId, '0', 'UNKNOWN', '', '', 0, 0, Result.UNKNOWN, 0);
        queryFootballData(game.gameId, JSON_FIXTURE, 2200000);
    }

    function evaluate() public {
        queryFootballData(game.gameId, JSON_RESULT, 400000);
    }

    function determineResult(uint homeTeam, uint awayTeam) constant returns (Result) {
        if (homeTeam > awayTeam) { return Result.HOMETEAMWIN; }
        if (homeTeam == awayTeam) { return Result.DRAW; }
        return Result.AWAYTEAMWIN;
    }

    function __callback(bytes32 myid, string result, bytes proof) public {
        __callback(myid, result);
    }

    function __callback(bytes32 myid, string result) public {
        Request memory r = requests[myid];

        if (r.initialized && !r.processed) {
            // new response
            if (r.key.toSlice().equals(JSON_FIXTURE.toSlice())) {
                var (success, tokens, numberTokens) = JsmnSol.parse(result, 45);
                if (success) {
                    for (uint k=0; k<=numberTokens; k++) {
                        // get Token contents
                        if (tokens[k].jsmnType == JsmnSol.JsmnType.STRING) {
                            string memory key = JsmnSol.getBytes(result, tokens[k]);
                            if (key.toSlice().equals(JSON_STATUS.toSlice())) {
                                game.status = JsmnSol.getBytes(result, tokens[++k]);
                            } else if (key.toSlice().equals(JSON_HOME_TEAM.toSlice())) {
                                game.homeTeam = JsmnSol.getBytes(result, tokens[++k]);
                            } else if (key.toSlice().equals(JSON_AWAY_TEAM.toSlice())) {
                                game.awayTeam = JsmnSol.getBytes(result, tokens[++k]);
                            }
                        }
                    }
                }
            } else if (r.key.toSlice().equals(JSON_RESULT.toSlice())) {
                (success, tokens, numberTokens) = JsmnSol.parse(result, 10);
                if (success) {
                    for (k=0; k<=numberTokens; k++) {
                        if (tokens[k].jsmnType == JsmnSol.JsmnType.STRING) {
                            key = JsmnSol.getBytes(result, tokens[k]);
                            if (key.toSlice().equals(JSON_AWAY_GOALS.toSlice())) {
                                game.awayTeamGoals = parseInt(JsmnSol.getBytes(result, tokens[++k]));
                            } else if (key.toSlice().equals(JSON_HOME_GOALS.toSlice())) {
                                game.homeTeamGoals = parseInt(JsmnSol.getBytes(result, tokens[++k]));
                            }
                        }
                    }
                    game.result = determineResult(game.homeTeamGoals, game.awayTeamGoals);
                }
            }

            Info(gameToString());
            requests[myid].processed = true;
        }
    }

    function placeBet(uint8 _bet) public payable {
        Bet memory b = Bet(msg.value, 0, msg.sender);
        bets[_bet].push(b);
        betSums[_bet] += msg.value;
        BetEvent(b.stake, b.win, b.sender);
    }

    function setWinners() {
        uint loosingStake = 0;

        if (game.result != Result.HOMETEAMWIN) {
            loosingStake += betSums[uint8(Result.HOMETEAMWIN)];
        }

        if (game.result != Result.AWAYTEAMWIN) {
            loosingStake += betSums[uint8(Result.AWAYTEAMWIN)];
        }

        if (game.result != Result.DRAW) {
            loosingStake += betSums[uint8(Result.DRAW)];
        }

        // determine the win per wei
        uint winPerWei = loosingStake / betSums[uint8(game.result)];

        for (uint i=0; i<bets[uint8(game.result)].length; i++) {
            Bet b = bets[uint8(game.result)][i];
            b.win = winPerWei * b.stake;
            BetEvent(b.stake, b.win, b.sender);
            pendingWithdrawals[b.sender] = b.stake + b.win;
        }
    }

    function withdraw() returns (bool) {
        uint amount = pendingWithdrawals[msg.sender];
        pendingWithdrawals[msg.sender] = 0;

        if (msg.sender.send(amount)) {
            return true;
        } else {
            pendingWithdrawals[msg.sender] = amount;
            return false;
        }
    }

    function gameToString() constant returns (string) {
        string memory result = 'unknown';
        if (game.result == Result.HOMETEAMWIN) { result = 'homeTeamWin'; }
        else if (game.result == Result.AWAYTEAMWIN) { result = 'awayTeamWin'; }
        else if (game.result == Result.DRAW) { result = 'draw'; }

        strings.slice[] memory parts = new strings.slice[](8);
        parts[0] = game.gameId.toSlice();
        parts[1] = game.date.toSlice();
        parts[2] = game.status.toSlice();
        parts[3] = game.homeTeam.toSlice();
        parts[4] = game.awayTeam.toSlice();
        parts[5] = uint2str(game.homeTeamGoals).toSlice();
        parts[6] = uint2str(game.awayTeamGoals).toSlice();
        parts[7] = result.toSlice();
        return ', '.toSlice().join(parts);
    }

    function bytes32ToString(bytes32 x) constant returns (string) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

}
