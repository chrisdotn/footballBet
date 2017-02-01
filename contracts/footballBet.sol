pragma solidity ^0.4.2;

contract footballBet {
    /*string public league = 'bl1';
    string public teamId = '7';
    string public group = '28';
    string public matchIdBvbFcb = '39893'; // FCB:BVB      ST28, 2017-04-08
    string public matchIdFcKBvb = '39769'; // FCK:BVB 1:0, ST14, 2016-12-10
    string public matchIdBvbMgb = '39756'; // BVB:MGB 4:1, ST13, 2016-12-03*/

    enum Result { HOMETEAMWIN, AWAYTEAMWIN, DRAW }


    struct Match {
        uint matchId;
        uint date;
        Team homeTeam;
        Team awayTeam;
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
    uint numberBets = 0;

    Match public match;


    function createBet(uint matchId, uint homeTeamId, string homeTeamName, uint awayTeamId, string awayTeamName) public {
        match = Match(matchId, Team(homeTeamId, homeTeamName), Team(awayTeamId, awayTeamName));
        //TODO fire oraclize query to get match data from API
    }

    function placeBet(Result bet) public payable {
        numberBets++;
        bets[numberBets] = Bet(bet, msg.value, 0, msg.sender);
    }

    function __callback(bytes32 myid, string result) public {
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
    }

}
