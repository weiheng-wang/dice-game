classdef player
    properties
        Score
        RoundScore
    end
    
    methods
        function [] = displayScore(player)
            disp(player.Score);
        end
        
        function [] = displayRoundScore(player)
            disp(player.RoundScore)
        end
    end
end