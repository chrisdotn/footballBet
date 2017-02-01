# JSON Path

Get the result for team 1 only if it's the 'Endergebnis' (`ResultTypeID = 2`)
and Team1 has more goals ("points") than Team2
```
$.MatchResults[?(@.ResultTypeID = 2), ?(@.PointsTeam1 > @.PointsTeam2)].PointsTeam1
```
