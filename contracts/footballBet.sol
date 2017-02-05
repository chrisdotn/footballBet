pragma solidity ^0.4.2;

import './lib/usingOraclize.sol';
import './lib/strings.sol';

contract FootballBet is usingOraclize {
    using strings for *;
    /*string public league = 'bl1';
    string public teamId = '7';
    string public group = '28';
    string public matchIdBvbFcb = '39893'; // FCB:BVB      ST28, 2017-04-08
    string public matchIdFcKBvb = '39769'; // FCK:BVB 1:0, ST14, 2016-12-10
    string public matchIdBvbMgb = '39756'; // BVB:MGB 4:1, ST13, 2016-12-03*/

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

    struct Team {
        uint id;
        string name;
    }

    struct Bet {
        Result bet;
        uint stake;
        uint win;
        address sender;
    }

    mapping (uint => Bet) bets;
    uint numberBets;

    struct Request {
        bool initialized;
        bool processed;
        string key;
    }

    mapping (bytes32 => Request) requests;
    Game game;

    event Info(string message);

    function FootballBet() {
        OAR = OraclizeAddrResolverI(0x35e50f57a7273e8ec5f27652add107e082ee31cd);
    }

    function generateUrl(string base, string id, string filter, string jsonPath) public returns (string) {
        strings.slice[] memory parts = new strings.slice[](7);
        parts[0] = 'json('.toSlice();
        parts[1] = base.toSlice();
        parts[2] = id.toSlice();
        parts[3] = filter.toSlice();
        parts[4] = ').fixture.'.toSlice();
        parts[5] = jsonPath.toSlice();
        return ''.toSlice().join(parts);
    }

    function queryFootballData(string gameId, string key) public {
        if (oraclize_getPrice('URL') > this.balance) {
            Info('Oraclize query was NOT sent, please add some ETH to cover for the query fee');
        } else {
            Info('Oraclize query was sent, standing by for the answer..');
            string memory url = generateUrl('http://api.football-data.org/v1/fixtures/', gameId, '?head2head=0', key);
            Info(url);
            bytes32 requestId = oraclize_query('URL', url);
            requests[requestId] = Request(true, false, key);
        }
    }

    function createBet(string gameId) public payable {
        game = Game(gameId, '0', 'UNKNOWN', '', '', 0, 0, Result.UNKNOWN, 0);
        queryFootballData(gameId, 'date');
        queryFootballData(game.gameId, 'status');
        queryFootballData(game.gameId, 'homeTeamName');
        queryFootballData(game.gameId, 'awayTeamName');
        queryFootballData(game.gameId, 'result.goalsHomeTeam');
        queryFootballData(game.gameId, 'result.goalsAwayTeam');
    }

    function gameToString() returns (string) {
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

    function requestToString(bytes32 id) public returns (string) {
        Request memory r = requests[id];
        strings.slice[] memory parts = new strings.slice[](5);
        parts[0] = 'REQUEST'.toSlice();
        parts[1] = r.key.toSlice();
        parts[2] = r.initialized ? 'true'.toSlice() : 'false'.toSlice();
        parts[3] = r.processed ? 'true'.toSlice() : 'false'.toSlice();
        return ', '.toSlice().join(parts);
    }

    function determineResult(uint homeTeam, uint awayTeam) internal returns (Result) {
        if (homeTeam > awayTeam) { return Result.HOMETEAMWIN; }
        if (homeTeam == awayTeam) { return Result.DRAW; }
        return Result.AWAYTEAMWIN;
    }

    function __callback(bytes32 myid, string result) public {
        Request memory r = requests[myid];

        if (r.initialized && !r.processed) {
            // new response
            if (r.key.toSlice().equals('date'.toSlice())) {
                game.date = result;
            } else if (r.key.toSlice().equals('status'.toSlice())) {
                game.status = result;
            } else if (r.key.toSlice().equals('homeTeamName'.toSlice())) {
                game.homeTeam = result;
            } else if (r.key.toSlice().equals('awayTeamName'.toSlice())) {
                game.awayTeam = result;
            } else if (r.key.toSlice().equals('result.goalsHomeTeam'.toSlice())) {
                game.homeTeamGoals = parseInt(result);
                game.receivedGoalMsgs++;
                if (game.receivedGoalMsgs != 2) {
                    game.result = determineResult(game.homeTeamGoals, game.awayTeamGoals);
                }
            } else if (r.key.toSlice().equals('result.goalsAwayTeam'.toSlice())) {
                game.awayTeamGoals = parseInt(result);
                game.receivedGoalMsgs++;
                if (game.receivedGoalMsgs != 2) {
                    game.result = determineResult(game.homeTeamGoals, game.awayTeamGoals);
                }
            }

            Info(gameToString());
            requests[myid].processed = true;
        }
    }
        /*
        TODO
        switch between callback to static query or result query
        STATIC
        - Determine if static query from createBet
        - Set values (in particular date)
        - setup query for results 4 hours after starttime
        RESULT
        - set status to CLOSED
        - determine winner
        - determine sum of loosing bets
        - distribute loosing bets to winning bets
        - set status to WITHDRAWEL
        */

    /*function placeBet(Result bet) public payable {
        numberBets++;
        bets[numberBets] = Bet(bet, msg.value, 0, msg.sender);
    }

    function splitElement(strings.slice s) internal returns (strings.slice value) {

        var delim = ':'.toSlice();
        s.split(delim, value);
        return value;
    }

    function processResult(string result) public {
        var s = result.toSlice();
        var delim = ','.toSlice();
        strings.slice memory part;
        mapping (string => strings.slice) elements;

        Info(result);
        uint numParts = s.count(delim);

        //var parts = new string[](s.count(delim));
        for (uint i = 0; i < numParts; i++) {
            s.split(delim, part);
            Info(part.toString());
            if (part.startsWith('"status"'.toSlice())) {
                elements['status'] = part;
            } else if (part.startsWith('"homeTeamName"'.toSlice())) {
                elements['homeTeamName'] = splitElement(part);
            } else if (part.startsWith('"awayTeamName"'.toSlice())) {
                elements['awayTeamName'] = splitElement(part);
            } else if (part.startsWith('"goalsAwayTeam"'.toSlice())) {
                elements['goalsAwayTeam'] = splitElement(part);
            } else if (part.startsWith('"result"'.toSlice())) {
                elements['goalsHomeTeam'] = splitElement(splitElement(part));
            }
        }
        Info(elements['status'].toString());
        Info(elements['homeTeamName'].toString());
        Info(elements['awayTeamName'].toString());
    }

    function process2(string result) public {
        strings.slice memory key;
        strings.slice memory value;
        (key, value) = split(result.toSlice());
        Info('K: '.toSlice().concat(key));
        Info('V: '.toSlice().concat(value));
    }

    function split(strings.slice s) internal returns (strings.slice key, strings.slice value) {
        s.beyond('{'.toSlice()).until('}'.toSlice());

        //strings.slice first = s.split
        key = s.split(':'.toSlice());
        value = s.beyond('{'.toSlice()).until('}'.toSlice());
    }*/


}
