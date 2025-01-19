classdef Dice_Game_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        PlayerSelection      matlab.ui.container.ButtonGroup
        Player2Button        matlab.ui.control.RadioButton
        Player1Button        matlab.ui.control.RadioButton
        CloseButton          matlab.ui.control.Button
        Rules                matlab.ui.control.Image
        StartButton          matlab.ui.control.Button
        RulesButton          matlab.ui.control.Button
        menu                 matlab.ui.control.Image
        Status               matlab.ui.control.TextArea
        StartanewgameButton  matlab.ui.control.Button
        Lose                 matlab.ui.control.Image
        Win                  matlab.ui.control.Image
        PLAYER2              matlab.ui.control.TextArea
        PLAYER1              matlab.ui.control.TextArea
        HOTDICE              matlab.ui.control.TextArea
        FARKLE               matlab.ui.control.TextArea
        RoundScoreDisplay    matlab.ui.control.TextArea
        CheckBox6            matlab.ui.control.CheckBox
        CheckBox5            matlab.ui.control.CheckBox
        CheckBox4            matlab.ui.control.CheckBox
        CheckBox3            matlab.ui.control.CheckBox
        CheckBox2            matlab.ui.control.CheckBox
        CheckBox             matlab.ui.control.CheckBox
        RDice6               matlab.ui.control.Image
        RDice5               matlab.ui.control.Image
        RDice4               matlab.ui.control.Image
        RDice3               matlab.ui.control.Image
        RDice2               matlab.ui.control.Image
        RDice1               matlab.ui.control.Image
        Dice6                matlab.ui.control.Image
        Dice5                matlab.ui.control.Image
        Dice4                matlab.ui.control.Image
        Dice3                matlab.ui.control.Image
        Dice2                matlab.ui.control.Image
        Dice1                matlab.ui.control.Image
        ScoreTable           matlab.ui.control.Table
        MeldsTable           matlab.ui.control.Table
        BankButton           matlab.ui.control.Button
        RollDiceButton       matlab.ui.control.Button
    end

    properties (Access = private)

        RolledDice % array of the rolled dice values
        SelectedDice % array of the selected dice values, unselected dice are zeros

        RollsLeft

        FirstScore % used to update roundscores based on checked dice

        HotDiceFlag
        
        GameStarted
        GameOver
        firstToHit10k % field 3
        
        myPlayerNum % field 1
        otherPlayerNum % field 1

        player1 % object, player class
        player2 % object, player class

        MyScore % field 2
        OtherScore % field 2

        MyRolls % field 4
        OtherRolls % field 4

        channelID
        writeKey
        readKey
        writeDelay
        readDelay

        % Audio
        diceroll
        farkle
        hotdice
        click
        win
        lose
        updatescore

    end

    
    methods (Access = private)
        
        function [] = WaitForOtherPlayer(app)
            
            app.disableCheckboxes();
            app.RollDiceButton.Enable = 'off';
            app.Status.Value = "Waiting...";
            
            playerWhoSentMsg = 0;
            
            while playerWhoSentMsg ~= app.otherPlayerNum
                data = thingSpeakRead(app.channelID, 'Fields', [1:5], 'ReadKey', ...
                    app.readKey);
                
                % to help with debugging
                disp("I am player " + num2str(app.myPlayerNum) ...
                    + " and I just read this data from the ThingSpeak channel:");
                disp(data);
                
                % the first number should 
                % always be the number of the player who
                % last wrote the data
                playerWhoSentMsg = data(1);

                % animations/waiting effects

                % delay before trying to read the online channel again
                pause(app.readDelay);              
            end
            
            % The second number represents the score 
            % by the other player.
            app.OtherScore = data(2);

            % for command window display
            app.player2.Score = app.OtherScore;
            app.player2.displayScore();

            if app.OtherScore ~= app.ScoreTable.Data(2,2)
                sound(app.updatescore);
                style = uistyle;
                style.BackgroundColor = [0.7, 0.9, 0.7]; % light green
                addStyle(app.ScoreTable, style, 'cell', [2, 2]);

                % update score animation
                for i=app.ScoreTable.Data(2,2):10:app.OtherScore
                    app.ScoreTable.Data(2,2) = i;
                    pause(0.02);
                end
                app.ScoreTable.Data(2,2) = app.OtherScore;
                pause(0.8);
                removeStyle(app.ScoreTable);
            end
            
            % The third number represents who was
            % first to hit 10k points.
            app.firstToHit10k = data(3);

            if app.firstToHit10k == 0 % no one hit 10k yet
                app.Status.Value = "Your turn!";
                app.RollDiceButton.Enable = 'on';
            elseif app.firstToHit10k == app.otherPlayerNum % redemption
                app.Status.Value = "Redemption...";
                app.RollDiceButton.Enable = 'on';
            elseif app.firstToHit10k == app.myPlayerNum % check after my player hits 10k and other player rolled
                if app.ScoreTable.Data(1,2) > app.ScoreTable.Data(2,2)
                    sound(app.win);
                    app.Win.Visible = 'on';
                    app.StartanewgameButton.Enable = 'on';
                    app.StartanewgameButton.Visible = 'on';
                    app.GameOver = 1;
                    app.Status.Value = "Congratulations! :D";
                elseif app.ScoreTable.Data(1,2) < app.ScoreTable.Data(2,2)
                    sound(app.lose);
                    app.Lose.Visible = 'on';
                    app.StartanewgameButton.Enable = 'on';
                    app.StartanewgameButton.Visible = 'on';
                    app.GameOver = 1;
                    app.Status.Value = "Get Better... :(";
                % if tie, it keeps on going
                else % tie
                    app.Status.Value = "Your turn!";
                    app.RollDiceButton.Enable = 'on';
                end
            end

            % The fourth and fifth numbers represent
            % the number of rolls for each player.
            if app.myPlayerNum == 1
                app.OtherRolls = data(5);
            elseif app.myPlayerNum == 2
                app.OtherRolls = data(4);
            end
            app.ScoreTable.Data(2,1) = app.OtherRolls;
        end
        

        function[] = ClearThinkSpeakChannel(app)
            thingSpeakWrite(app.channelID, 'WriteKey', app.writeKey, ...
                'Fields', [1:5], 'Values', [0,0,0,0,0]);
        end


        function [] = SendDataToOtherPlayer(app)
            pause(app.writeDelay);
            if app.myPlayerNum == 1
                data = [app.myPlayerNum, app.MyScore, app.firstToHit10k, app.MyRolls, app.OtherRolls];
            elseif app.myPlayerNum == 2
                data = [app.myPlayerNum, app.MyScore, app.firstToHit10k, app.OtherRolls, app.MyRolls];
            end
            
            disp("I sent this data to the ThingSpeak channel: ");
            disp(data);
            
            thingSpeakWrite(app.channelID, 'WriteKey', app.writeKey, ...
            'Fields', [1:5], 'Values', data)
        end


        function updateDiceImages(app, rolledValues) % red dice, 1-6
            pathToMLAPP = fileparts(mfilename('fullpath'));
            app.RDice1.ImageSource = fullfile(pathToMLAPP, ['DR', num2str(rolledValues(1)), '.png']);
            app.RDice2.ImageSource = fullfile(pathToMLAPP, ['DR', num2str(rolledValues(2)), '.png']);
            app.RDice3.ImageSource = fullfile(pathToMLAPP, ['DR', num2str(rolledValues(3)), '.png']);
            app.RDice4.ImageSource = fullfile(pathToMLAPP, ['DR', num2str(rolledValues(4)), '.png']);
            app.RDice5.ImageSource = fullfile(pathToMLAPP, ['DR', num2str(rolledValues(5)), '.png']);
            app.RDice6.ImageSource = fullfile(pathToMLAPP, ['DR', num2str(rolledValues(6)), '.png']);
        end


        function importAudio(app)
            app.diceroll = audioread('diceroll.wav');
            app.farkle = audioread('farkle.wav');
            app.hotdice = audioread('hotdice.wav');
            app.click = audioread('click.wav');
            app.win = audioread('win.wav');
            app.lose = audioread('lose.wav');
            app.updatescore = audioread('updatescore.wav');
        end

        
        function [score, isFarkle, isHotDice, meldIndices] = checkDiceValue(app, selectedDice, selectedIndices) % doesn't actually update score
            score = 0;
            isFarkle = false;
            isHotDice = false;

            meldIndices = [];

            counts = histcounts(selectedDice, 1:7);

            % straight (1-2-3-4-5-6)
            if all(counts == 1)
                score = score + 1500;
                meldIndices = selectedIndices;
                isHotDice = true;
                return;
            end
            
            % three pairs
            if nnz(counts == 2) == 3
                score = score + 1500;
                meldIndices = selectedIndices;
                isHotDice = true;
                return;
            end
            
            % two sets of three
            if nnz(counts >= 3) == 2
                score = score + 2500;
                meldIndices = selectedIndices;
                isHotDice = true;
                return;
            end
            
            % four of a kind + a pair
            if any(counts == 4) && any(counts == 2)
                score = score + 1500;
                meldIndices = selectedIndices;
                isHotDice = true;
                return;
            end
            
            % four, five, or six of a kind
            for i = 1:6
                if counts(i) == 4
                    score = score + 1000;
                    meldIndices = [meldIndices, app.findMeldIndices(selectedDice, selectedIndices, i, 4)];
                    counts(i) = 0;
                elseif counts(i) == 5
                    score = score + 2000;
                    meldIndices = [meldIndices, app.findMeldIndices(selectedDice, selectedIndices, i, 5)];
                    counts(i) = 0;
                elseif counts(i) == 6
                    score = score + 3000;
                    meldIndices = [meldIndices, app.findMeldIndices(selectedDice, selectedIndices, i, 6)];
                    counts(i) = 0;
                end
            end
            
            % three of a kind
            for i = 1:6
                if counts(i) >= 3
                    if i == 1
                        score = score + 1000;
                    else
                        score = score + i * 100;
                    end
                    meldIndices = [meldIndices, app.findMeldIndices(selectedDice, selectedIndices, i, 3)];
                    counts(i) = counts(i) - 3;
                end
            end
            
            % single 1s and 5s
            meldIndices = [meldIndices, app.findMeldIndices(selectedDice, selectedIndices, 1, counts(1))];
            score = score + counts(1) * 100; % 1s are 100 points each

            meldIndices = [meldIndices, app.findMeldIndices(selectedDice, selectedIndices, 5, counts(5))];
            score = score + counts(5) * 50;  % 5s are 50 points each
            
            % Farkle? (no dice score points)
            if score == 0
                isFarkle = true;
            end
            
            % Hot Dice? (all dice score points)
            if all(ismember(selectedIndices, meldIndices))
                isHotDice = true;
            end

            meldIndices = unique(meldIndices);
        end


        function meldIndices = findMeldIndices(~, selectedDice, selectedIndices, value, count)
            % find indices of dice forming a meld
            logicalArray = selectedDice == value;
            selectedIndicesArray = find(logicalArray);
            meldIndices = [];
            
            for i = 1:min(count, length(selectedIndicesArray))
                meldIndices = [meldIndices, selectedIndices(selectedIndicesArray(i))];
            end
        end


        function enableMeldCheckboxes(app, meldIndices)
            for i = 1:length(meldIndices)
                switch meldIndices(i)
                    case 1
                        app.CheckBox.Enable = 'on';
                    case 2
                        app.CheckBox2.Enable = 'on';
                    case 3
                        app.CheckBox3.Enable = 'on';
                    case 4
                        app.CheckBox4.Enable = 'on';
                    case 5
                        app.CheckBox5.Enable = 'on';
                    case 6
                        app.CheckBox6.Enable = 'on';
                end
            end
        end


        function updateScore(app)

            currentScore = app.ScoreTable.Data(1,2);
            newScore = currentScore + str2double(app.RoundScoreDisplay.Value);

            if newScore ~= currentScore
                sound(app.updatescore);
                style = uistyle;
                style.BackgroundColor = [0.7, 0.9, 0.7]; % light green
                addStyle(app.ScoreTable, style, 'cell', [1, 2]);
                app.RoundScoreDisplay.Value = '0';
                
                % update score animation
                for i=currentScore:10:newScore
                    app.ScoreTable.Data(1,2) = i;
                    pause(0.02);
                end
                app.ScoreTable.Data(1,2) = newScore;
                pause(0.8);
                removeStyle(app.ScoreTable);
    
                if newScore >= 1000 && app.firstToHit10k == 0 % change to 10k
                    app.firstToHit10k = app.myPlayerNum;
                end
            end
            
            if app.firstToHit10k == app.otherPlayerNum % check after other player hits 10k and my player rolled
                if app.ScoreTable.Data(1,2) > app.ScoreTable.Data(2,2)
                    sound(app.win);
                    app.Win.Visible = 'on';
                    app.StartanewgameButton.Enable = 'on';
                    app.StartanewgameButton.Visible = 'on';
                    app.GameOver = 1;
                    app.Status.Value = "Congratulations! :D";
                elseif app.ScoreTable.Data(1,2) < app.ScoreTable.Data(2,2)
                    sound(app.lose);
                    app.Lose.Visible = 'on';
                    app.StartanewgameButton.Enable = 'on';
                    app.StartanewgameButton.Visible = 'on';
                    app.GameOver = 1;
                    app.Status.Value = "Get Better... :(";
                % if tie, it keeps on going
                end
            end

            app.MyScore = newScore;

            % for command window display
            app.player1.Score = app.MyScore;
            app.player1.displayScore();

            app.SendDataToOtherPlayer();
            
        end


        function clearCheckboxes(app)
            app.CheckBox.Value = 0;
            app.CheckBox2.Value = 0;
            app.CheckBox3.Value = 0;
            app.CheckBox4.Value = 0;
            app.CheckBox5.Value = 0;
            app.CheckBox6.Value = 0;
        end


        function fillCheckboxes(app)
            app.CheckBox.Value = 1;
            app.CheckBox2.Value = 1;
            app.CheckBox3.Value = 1;
            app.CheckBox4.Value = 1;
            app.CheckBox5.Value = 1;
            app.CheckBox6.Value = 1;
        end


        function enableCheckboxes(app)
            app.CheckBox.Enable = 'on';
            app.CheckBox2.Enable = 'on';
            app.CheckBox3.Enable = 'on';
            app.CheckBox4.Enable = 'on';
            app.CheckBox5.Enable = 'on';
            app.CheckBox6.Enable = 'on';
        end


        function disableCheckboxes(app)
            app.CheckBox.Enable = 'off';
            app.CheckBox2.Enable = 'off';
            app.CheckBox3.Enable = 'off';
            app.CheckBox4.Enable = 'off';
            app.CheckBox5.Enable = 'off';
            app.CheckBox6.Enable = 'off';
        end


        function endTurn(app)

            app.FARKLE.Visible = 'off';
            app.HOTDICE.Visible = 'off';
            app.HotDiceFlag = 0;
            app.BankButton.Enable = 'off';

            if app.GameOver == 0
                app.updateDiceImages([1,2,3,4,5,6]);
                app.RollsLeft = 2;
                app.RolledDice = zeros(1,6);
                app.SelectedDice = zeros(1,6);
                app.FirstScore = 0;
                app.clearCheckboxes();

                app.WaitForOtherPlayer();
            end
        end


        function reset(app)
            
            % Dice Initialization
            app.RolledDice = zeros(1,6);
            app.SelectedDice = zeros(1,6);

            app.updateDiceImages([1,2,3,4,5,6]);

            app.disableCheckboxes();
            app.clearCheckboxes();

            app.RollsLeft = 2;

            % Num Rolls
            app.MyRolls = 0;
            app.OtherRolls = 0;

            app.FirstScore = 0;
            
            % Round Score Text
            app.RoundScoreDisplay.Value = '0';

            % Rolls/Scores Table
            data = zeros(2,2);
            app.ScoreTable.Data = data;

            % Hot Dice Flag
            app.HotDiceFlag = 0;

            % Game
            app.GameStarted = 0;
            app.GameOver = 0;
            app.firstToHit10k = 0;

            % Scores
            app.MyScore = 0; % current player's score
            app.OtherScore = 0; % other player's score
            
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)

            % Background
            app.UIFigure.Color = [79/255, 107/255, 86/255]; % dark green
         
            % Meld/Value Table
            col1 = {'Ones', 'Fives', 'Triple one', 'Triple two', 'Triple three',...
                    'Triple four', 'Triple five', 'Triple six', 'Four of a kind',...
                    'Five of a kind', 'Six of a kind', 'Three pairs', 'Full run'};
            col2 = {100, 50, 1000, 200, 300, 400, 500, 600, 1000, 2000, 3000, 1500, 2500};
            data = [col1', col2'];
            app.MeldsTable.Data = data;

            % Rolls/Scores Table
            app.ScoreTable.RowName = {'You', 'Opponent'};
            app.ScoreTable.ColumnWidth = {'fit', '100x'};

            % Audio
            app.importAudio();

            % ThingSpeak
            app.channelID = 2566706;
            app.writeKey = '119QIKV3IH4MCWGL';
            app.readKey = 'KJY25OL9COHGWWCA';
            
            app.readDelay = 5;
            app.writeDelay = 1;

            % Player Nums (1/2)
            app.myPlayerNum = 1;
            app.otherPlayerNum = 2;

            % Player Class
            app.player1 = player;
            app.player2 = player;
            app.player1.Score = 0;
            app.player1.RoundScore = 0;
            app.player2.Score = 0;
            app.player2.RoundScore = 0;

            app.reset();
            app.ClearThinkSpeakChannel();
            
        end

        % Button pushed function: RollDiceButton
        function RollDiceButtonPushed(app, event)
            
            app.MyRolls = app.MyRolls + 1;
            app.ScoreTable.Data(1,1) = app.MyRolls;

            skipRest = false;

            app.RollDiceButton.Enable = 'off';

            app.FARKLE.Visible = 'off';
            app.HOTDICE.Visible = 'off';

            if app.RollsLeft > 0

                sound(app.diceroll);

                if app.HotDiceFlag % player rolled after hot dice so all checkboxes reset, meld checkboxes enabled later
                    app.clearCheckboxes();
                    app.enableCheckboxes();
                    app.SelectedDice = zeros(1,6);
                    app.HotDiceFlag = 0;
                end

                % roll dice animation
                pathToMLAPP = fileparts(mfilename('fullpath'));
                for i=1:10
                    for j=1:6
                        if app.SelectedDice(j) == 0
                            randNum = randi(6);
                            imagePath = fullfile(pathToMLAPP, ['DR', num2str(randNum), '.png']);
                            switch j
                                case 1
                                    app.RDice1.ImageSource = imagePath;
                                case 2
                                    app.RDice2.ImageSource = imagePath;
                                case 3
                                    app.RDice3.ImageSource = imagePath;
                                case 4
                                    app.RDice4.ImageSource = imagePath;
                                case 5
                                    app.RDice5.ImageSource = imagePath;
                                case 6
                                    app.RDice6.ImageSource = imagePath;
                            end
                        end
                    end
                    pause(0.05);
                end

                % actual rolling of dice
                for i=1:6
                    if app.SelectedDice(i) == 0
                        app.RolledDice(i) = randi(6);                        
                    end
                end

                updateDiceImages(app, app.RolledDice); % only update newly rolled dice
                unselected = app.SelectedDice == 0;
                newRolled = app.RolledDice(unselected);
                indices = find(unselected);
                [score, isFarkle, isHotDice, ~] = app.checkDiceValue(newRolled, indices);
                if isFarkle
                    sound(app.farkle);
                    app.RoundScoreDisplay.Value = '0';
                    app.disableCheckboxes();
                    app.RollsLeft = 0;
                    app.FARKLE.Visible = 'on';
                    app.RollDiceButton.Enable = 'off';
                    app.BankButton.Enable = 'off';
                    skipRest = true;
                    app.RoundScoreDisplay.BackgroundColor = [1, 0.6, 0.6]; % light red
                    pause(0.5);
                    app.RoundScoreDisplay.BackgroundColor = [1, 1, 1];
                    app.updateScore();
                    % end turn
                    pause(1.5);
                    app.endTurn();

                elseif isHotDice
                    sound(app.hotdice);
                    app.fillCheckboxes();
                    app.SelectedDice = app.RolledDice;
                    app.RoundScoreDisplay.Value = num2str(str2double(app.RoundScoreDisplay.Value) + score);
                    app.disableCheckboxes();
                    app.RollsLeft = 1;
                    app.HOTDICE.Visible = 'on';
                    skipRest = true;
                    app.RollDiceButton.Enable = 'on';
                    app.BankButton.Enable = 'on';
                    app.HotDiceFlag = 1;
                end

                if ~skipRest % if not farkle nor hot dice, i.e. normal roll
                    app.RollsLeft = app.RollsLeft - 1;
                end
            end

            if ~skipRest % if not farkle nor hot dice, i.e. normal roll
                if app.RollsLeft == 1 % when player has rolled once
                    app.BankButton.Enable = 'on';
                    app.BankButton.Visible = 'on';
                    [~, ~, ~, meldDice] = app.checkDiceValue(app.RolledDice, [1,2,3,4,5,6]); % check all dice since all newly rolled
                    % enable corresponding checkboxes
                    enableMeldCheckboxes(app, meldDice);

                elseif app.RollsLeft == 0 % all rolls after the first roll
                    app.RollsLeft = app.RollsLeft + 1;
                    app.FirstScore = str2double(app.RoundScoreDisplay.Value); % store score from melds to use when updating roundscore
    
                    app.disableCheckboxes(); % disable all (in case dice from previous round was enabled)

                    x = app.SelectedDice ~= 0; % selected dice (from last round)
                    selectedIndices = find(x);

                    if any(x)
                        % previously selected dice become black
                        pathToMLAPP = fileparts(mfilename('fullpath'));
                        for i=1:length(selectedIndices)
                            switch selectedIndices(i)
                                case 1
                                    app.RDice1.ImageSource = fullfile(pathToMLAPP, ['D', num2str(app.SelectedDice(1)), '.png']);
                                case 2
                                    app.RDice2.ImageSource = fullfile(pathToMLAPP, ['D', num2str(app.SelectedDice(2)), '.png']);
                                case 3
                                    app.RDice3.ImageSource = fullfile(pathToMLAPP, ['D', num2str(app.SelectedDice(3)), '.png']);
                                case 4
                                    app.RDice4.ImageSource = fullfile(pathToMLAPP, ['D', num2str(app.SelectedDice(4)), '.png']);
                                case 5
                                    app.RDice5.ImageSource = fullfile(pathToMLAPP, ['D', num2str(app.SelectedDice(5)), '.png']);
                                case 6
                                    app.RDice6.ImageSource = fullfile(pathToMLAPP, ['D', num2str(app.SelectedDice(6)), '.png']);
                            end
                        end
                    end
    
                    y = app.SelectedDice == 0; % unselected dice (newly rolled)
                    unselectedIndices = find(y);
                    [~, ~, ~, meldDice] = app.checkDiceValue(app.RolledDice(y), unselectedIndices);
                    % enable corresponding checkboxes
                    enableMeldCheckboxes(app, meldDice);
                end
            end

        end

        % Button pushed function: BankButton
        function BankButtonPushed(app, event)

            app.BankButton.Enable = 'off';
            app.RollsLeft = 0;
            app.RollDiceButton.Enable = 'off';

            checkBoxLocs = [app.CheckBox.Enable, app.CheckBox2.Enable, app.CheckBox3.Enable, app.CheckBox4.Enable,...
                app.CheckBox5.Enable, app.CheckBox6.Enable];
            stillEnabled = app.RolledDice(checkBoxLocs); % still enabled => can make melds
            indices = find(checkBoxLocs);
            [score, ~, ~, meldDice] = app.checkDiceValue(stillEnabled, indices);

            if ~app.HotDiceFlag
                % unecessary if hot dice rolled, roundscore already
                % updated and all checkboxes checked
                app.RoundScoreDisplay.Value = num2str(app.FirstScore + score);
    
                % check corresponding checkboxes
                for i = 1:length(meldDice)
                    switch meldDice(i)
                        case 1
                            app.CheckBox.Value = 1;
                        case 2
                            app.CheckBox2.Value = 1;
                        case 3
                            app.CheckBox3.Value = 1;
                        case 4
                            app.CheckBox4.Value = 1;
                        case 5
                            app.CheckBox5.Value = 1;
                        case 6
                            app.CheckBox6.Value = 1;
                    end
                end
            end

            app.disableCheckboxes();
            pause(1);
            app.updateScore();
            % end turn
            app.endTurn();

        end

        % Button pushed function: RulesButton
        function RulesButtonPushed(app, event)
            app.Rules.Visible = 'on';
            app.CloseButton.Visible = 'on';
            app.CloseButton.Enable = 'on';
            app.StartButton.Visible = 'off';
            app.StartButton.Enable = 'off';
            app.PlayerSelection.Visible = 'off';
            app.Status.Visible = 'off';
        end

        % Value changed function: CheckBox
        function CheckBoxValueChanged(app, event)
            % comments the same for all checkbox value changed fcns
            sound(app.click);
            value = app.CheckBox.Value;
            if value == 1 % if checked
                app.SelectedDice(1) = app.RolledDice(1);
            elseif value == 0 % if unchecked
                app.SelectedDice(1) = 0;
            end
            checkBoxLocs = [app.CheckBox.Enable, app.CheckBox2.Enable, app.CheckBox3.Enable, app.CheckBox4.Enable,...
                app.CheckBox5.Enable, app.CheckBox6.Enable]; % only using newly rolled
            selectedLocs = app.SelectedDice ~= 0; % only using user-selected dice
            locs = checkBoxLocs & selectedLocs;
            checkedDice = app.SelectedDice(locs);
            indices = find(locs);
            [score, ~, ~, meldIndices] = app.checkDiceValue(checkedDice, indices);
            app.RoundScoreDisplay.Value = num2str(app.FirstScore + score);
            if all(ismember(indices, meldIndices)) && ~isempty(indices) % roll dice button enabled only if newly selected dice form meld
                app.RollDiceButton.Enable = 'on';
            else
                app.RollDiceButton.Enable = 'off';
            end
            % for command window display
            app.player1.RoundScore = str2double(app.RoundScoreDisplay.Value);
            app.player1.displayRoundScore();
        end

        % Value changed function: CheckBox2
        function CheckBox2ValueChanged(app, event)
            sound(app.click);
            value = app.CheckBox2.Value;
            if value == 1
                app.SelectedDice(2) = app.RolledDice(2);
            elseif value == 0
                app.SelectedDice(2) = 0;
            end
            checkBoxLocs = [app.CheckBox.Enable, app.CheckBox2.Enable, app.CheckBox3.Enable, app.CheckBox4.Enable,...
                app.CheckBox5.Enable, app.CheckBox6.Enable];
            selectedLocs = app.SelectedDice ~= 0;
            locs = checkBoxLocs & selectedLocs;
            checkedDice = app.SelectedDice(locs);
            indices = find(locs);
            [score, ~, ~, meldIndices] = app.checkDiceValue(checkedDice, indices);
            app.RoundScoreDisplay.Value = num2str(app.FirstScore + score);
            if all(ismember(indices, meldIndices)) && ~isempty(indices)
                app.RollDiceButton.Enable = 'on';
            else
                app.RollDiceButton.Enable = 'off';
            end
            app.player1.RoundScore = str2double(app.RoundScoreDisplay.Value);
            app.player1.displayRoundScore();
        end

        % Value changed function: CheckBox3
        function CheckBox3ValueChanged(app, event)
            sound(app.click);
            value = app.CheckBox3.Value;
            if value == 1
                app.SelectedDice(3) = app.RolledDice(3);
            elseif value == 0
                app.SelectedDice(3) = 0;
            end
            checkBoxLocs = [app.CheckBox.Enable, app.CheckBox2.Enable, app.CheckBox3.Enable, app.CheckBox4.Enable,...
                app.CheckBox5.Enable, app.CheckBox6.Enable];
            selectedLocs = app.SelectedDice ~= 0;
            locs = checkBoxLocs & selectedLocs;
            checkedDice = app.SelectedDice(locs);
            indices = find(locs);
            [score, ~, ~, meldIndices] = app.checkDiceValue(checkedDice, indices);
            app.RoundScoreDisplay.Value = num2str(app.FirstScore + score);
            if all(ismember(indices, meldIndices)) && ~isempty(indices)
                app.RollDiceButton.Enable = 'on';
            else
                app.RollDiceButton.Enable = 'off';
            end
            app.player1.RoundScore = str2double(app.RoundScoreDisplay.Value);
            app.player1.displayRoundScore();
        end

        % Value changed function: CheckBox4
        function CheckBox4ValueChanged(app, event)
            sound(app.click);
            value = app.CheckBox4.Value;
            if value == 1
                app.SelectedDice(4) = app.RolledDice(4);
            elseif value == 0
                app.SelectedDice(4) = 0;
            end
            checkBoxLocs = [app.CheckBox.Enable, app.CheckBox2.Enable, app.CheckBox3.Enable, app.CheckBox4.Enable,...
                app.CheckBox5.Enable, app.CheckBox6.Enable];
            selectedLocs = app.SelectedDice ~= 0;
            locs = checkBoxLocs & selectedLocs;
            checkedDice = app.SelectedDice(locs);
            indices = find(locs);
            [score, ~, ~, meldIndices] = app.checkDiceValue(checkedDice, indices);
            app.RoundScoreDisplay.Value = num2str(app.FirstScore + score);
            if all(ismember(indices, meldIndices)) && ~isempty(indices)
                app.RollDiceButton.Enable = 'on';
            else
                app.RollDiceButton.Enable = 'off';
            end
            app.player1.RoundScore = str2double(app.RoundScoreDisplay.Value);
            app.player1.displayRoundScore();
        end

        % Value changed function: CheckBox5
        function CheckBox5ValueChanged(app, event)
            sound(app.click);
            value = app.CheckBox5.Value;
            if value == 1
                app.SelectedDice(5) = app.RolledDice(5);
            elseif value == 0
                app.SelectedDice(5) = 0;
            end
            checkBoxLocs = [app.CheckBox.Enable, app.CheckBox2.Enable, app.CheckBox3.Enable, app.CheckBox4.Enable,...
                app.CheckBox5.Enable, app.CheckBox6.Enable];
            selectedLocs = app.SelectedDice ~= 0;
            locs = checkBoxLocs & selectedLocs;
            checkedDice = app.SelectedDice(locs);
            indices = find(locs);
            [score, ~, ~, meldIndices] = app.checkDiceValue(checkedDice, indices);
            app.RoundScoreDisplay.Value = num2str(app.FirstScore + score);
            if all(ismember(indices, meldIndices)) && ~isempty(indices)
                app.RollDiceButton.Enable = 'on';
            else
                app.RollDiceButton.Enable = 'off';
            end
            app.player1.RoundScore = str2double(app.RoundScoreDisplay.Value);
            app.player1.displayRoundScore();
        end

        % Value changed function: CheckBox6
        function CheckBox6ValueChanged(app, event)
            sound(app.click);
            value = app.CheckBox6.Value;
            if value == 1
                app.SelectedDice(6) = app.RolledDice(6);
            elseif value == 0
                app.SelectedDice(6) = 0;
            end
            checkBoxLocs = [app.CheckBox.Enable, app.CheckBox2.Enable, app.CheckBox3.Enable, app.CheckBox4.Enable,...
                app.CheckBox5.Enable, app.CheckBox6.Enable];
            selectedLocs = app.SelectedDice ~= 0;
            locs = checkBoxLocs & selectedLocs;
            checkedDice = app.SelectedDice(locs);
            indices = find(locs);
            [score, ~, ~, meldIndices] = app.checkDiceValue(checkedDice, indices);
            app.RoundScoreDisplay.Value = num2str(app.FirstScore + score);    
            if all(ismember(indices, meldIndices)) && ~isempty(indices)
                app.RollDiceButton.Enable = 'on';
            else
                app.RollDiceButton.Enable = 'off';
            end
            app.player1.RoundScore = str2double(app.RoundScoreDisplay.Value);
            app.player1.displayRoundScore();
        end

        % Button pushed function: CloseButton
        function CloseButtonPushed(app, event)
            app.Rules.Visible = 'off';
            app.CloseButton.Visible = 'off';
            app.CloseButton.Enable = 'off';
            app.Status.Visible = 'on';
            if ~app.GameStarted
                app.menu.Visible = 'on';
                app.StartButton.Visible = 'on';
                app.StartButton.Enable = 'on';
                app.PlayerSelection.Visible = 'on';
            end
        end

        % Button pushed function: StartanewgameButton
        function StartanewgameButtonPushed(app, event)
            % need to wait before restarting, thingspeak write delay
            clear sound;
            app.StartanewgameButton.Enable = 'off';
            app.StartanewgameButton.Visible = 'off';
            app.Win.Visible = 'off';
            app.Lose.Visible = 'off';
            app.reset();
            app.ClearThinkSpeakChannel();
            
            if app.myPlayerNum == 1
                app.RollDiceButton.Enable = 'on';
                app.Status.Value = "Your turn!";
            elseif app.myPlayerNum == 2
                app.Status.Value = "Waiting...";
            end
        end

        % Selection changed function: PlayerSelection
        function PlayerSelectionSelectionChanged(app, event)
            selectedButton = app.PlayerSelection.SelectedObject;
            if selectedButton == app.Player1Button
                app.myPlayerNum = 1;
                app.otherPlayerNum = 2;
            else
                app.myPlayerNum = 2;
                app.otherPlayerNum = 1;
            end
        end

        % Button pushed function: StartButton
        function StartButtonPushed(app, event)
            clear sound;
            
            set(app.Player1Button, 'Enable', 'off');
            set(app.Player2Button, 'Enable', 'off');
            set(app.StartButton, 'Enable', 'off');
            set(app.Player1Button, 'Visible', 'off');
            set(app.Player2Button, 'Visible', 'off');
            set(app.StartButton, 'Visible', 'off');
            set(app.PlayerSelection, 'Visible', 'off');
            set(app.menu, 'Visible', 'off');

            app.GameStarted = 1;

            if (app.myPlayerNum == 1)
                app.RollDiceButton.Enable = 'on';
                app.Status.Value = "Your turn!";
                app.PLAYER1.Visible = 'on';
            elseif (app.myPlayerNum == 2)
                app.PLAYER2.Visible = 'on';
                app.WaitForOtherPlayer();
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.Resize = 'off';
            app.UIFigure.Pointer = 'hand';

            % Create RollDiceButton
            app.RollDiceButton = uibutton(app.UIFigure, 'push');
            app.RollDiceButton.ButtonPushedFcn = createCallbackFcn(app, @RollDiceButtonPushed, true);
            app.RollDiceButton.Enable = 'off';
            app.RollDiceButton.Position = [84 101 100 23];
            app.RollDiceButton.Text = 'Roll Dice';

            % Create BankButton
            app.BankButton = uibutton(app.UIFigure, 'push');
            app.BankButton.ButtonPushedFcn = createCallbackFcn(app, @BankButtonPushed, true);
            app.BankButton.Enable = 'off';
            app.BankButton.Position = [252 101 100 23];
            app.BankButton.Text = 'Bank';

            % Create MeldsTable
            app.MeldsTable = uitable(app.UIFigure);
            app.MeldsTable.ColumnName = {'Meld'; 'Value'; 'Column 3'; 'Column 4'};
            app.MeldsTable.RowName = {};
            app.MeldsTable.Position = [458 22 169 327];

            % Create ScoreTable
            app.ScoreTable = uitable(app.UIFigure);
            app.ScoreTable.ColumnName = {'Rolls'; 'Points'; ''; 'Column 4'};
            app.ScoreTable.RowName = {};
            app.ScoreTable.Position = [458 366 169 75];

            % Create Dice1
            app.Dice1 = uiimage(app.UIFigure);
            app.Dice1.Visible = 'off';
            app.Dice1.Position = [84 283 76 76];
            app.Dice1.ImageSource = fullfile(pathToMLAPP, 'D1.png');

            % Create Dice2
            app.Dice2 = uiimage(app.UIFigure);
            app.Dice2.Visible = 'off';
            app.Dice2.Position = [180 283 76 76];
            app.Dice2.ImageSource = fullfile(pathToMLAPP, 'D2.png');

            % Create Dice3
            app.Dice3 = uiimage(app.UIFigure);
            app.Dice3.Visible = 'off';
            app.Dice3.Position = [276 283 76 76];
            app.Dice3.ImageSource = fullfile(pathToMLAPP, 'D3.png');

            % Create Dice4
            app.Dice4 = uiimage(app.UIFigure);
            app.Dice4.Visible = 'off';
            app.Dice4.Position = [84 172 76 76];
            app.Dice4.ImageSource = fullfile(pathToMLAPP, 'D4.png');

            % Create Dice5
            app.Dice5 = uiimage(app.UIFigure);
            app.Dice5.Visible = 'off';
            app.Dice5.Position = [180 172 76 76];
            app.Dice5.ImageSource = fullfile(pathToMLAPP, 'D5.png');

            % Create Dice6
            app.Dice6 = uiimage(app.UIFigure);
            app.Dice6.Visible = 'off';
            app.Dice6.Position = [276 172 76 76];
            app.Dice6.ImageSource = fullfile(pathToMLAPP, 'D6.png');

            % Create RDice1
            app.RDice1 = uiimage(app.UIFigure);
            app.RDice1.Position = [84 283 76 76];
            app.RDice1.ImageSource = fullfile(pathToMLAPP, 'DR1.png');

            % Create RDice2
            app.RDice2 = uiimage(app.UIFigure);
            app.RDice2.Position = [180 283 76 76];
            app.RDice2.ImageSource = fullfile(pathToMLAPP, 'DR2.png');

            % Create RDice3
            app.RDice3 = uiimage(app.UIFigure);
            app.RDice3.Position = [276 283 76 76];
            app.RDice3.ImageSource = fullfile(pathToMLAPP, 'DR3.png');

            % Create RDice4
            app.RDice4 = uiimage(app.UIFigure);
            app.RDice4.Position = [84 172 76 76];
            app.RDice4.ImageSource = fullfile(pathToMLAPP, 'DR4.png');

            % Create RDice5
            app.RDice5 = uiimage(app.UIFigure);
            app.RDice5.Position = [180 172 76 76];
            app.RDice5.ImageSource = fullfile(pathToMLAPP, 'DR5.png');

            % Create RDice6
            app.RDice6 = uiimage(app.UIFigure);
            app.RDice6.Position = [276 172 76 76];
            app.RDice6.ImageSource = fullfile(pathToMLAPP, 'DR6.png');

            % Create CheckBox
            app.CheckBox = uicheckbox(app.UIFigure);
            app.CheckBox.ValueChangedFcn = createCallbackFcn(app, @CheckBoxValueChanged, true);
            app.CheckBox.Enable = 'off';
            app.CheckBox.Text = '';
            app.CheckBox.Position = [115 261 14 22];

            % Create CheckBox2
            app.CheckBox2 = uicheckbox(app.UIFigure);
            app.CheckBox2.ValueChangedFcn = createCallbackFcn(app, @CheckBox2ValueChanged, true);
            app.CheckBox2.Enable = 'off';
            app.CheckBox2.Text = '';
            app.CheckBox2.Position = [211 261 14 22];

            % Create CheckBox3
            app.CheckBox3 = uicheckbox(app.UIFigure);
            app.CheckBox3.ValueChangedFcn = createCallbackFcn(app, @CheckBox3ValueChanged, true);
            app.CheckBox3.Enable = 'off';
            app.CheckBox3.Text = '';
            app.CheckBox3.Position = [307 261 14 22];

            % Create CheckBox4
            app.CheckBox4 = uicheckbox(app.UIFigure);
            app.CheckBox4.ValueChangedFcn = createCallbackFcn(app, @CheckBox4ValueChanged, true);
            app.CheckBox4.Enable = 'off';
            app.CheckBox4.Text = '';
            app.CheckBox4.Position = [115 150 14 22];

            % Create CheckBox5
            app.CheckBox5 = uicheckbox(app.UIFigure);
            app.CheckBox5.ValueChangedFcn = createCallbackFcn(app, @CheckBox5ValueChanged, true);
            app.CheckBox5.Enable = 'off';
            app.CheckBox5.Text = '';
            app.CheckBox5.Position = [211 150 14 22];

            % Create CheckBox6
            app.CheckBox6 = uicheckbox(app.UIFigure);
            app.CheckBox6.ValueChangedFcn = createCallbackFcn(app, @CheckBox6ValueChanged, true);
            app.CheckBox6.Enable = 'off';
            app.CheckBox6.Text = '';
            app.CheckBox6.Position = [307 150 14 22];

            % Create RoundScoreDisplay
            app.RoundScoreDisplay = uitextarea(app.UIFigure);
            app.RoundScoreDisplay.Editable = 'off';
            app.RoundScoreDisplay.Position = [197 60 42 23];

            % Create FARKLE
            app.FARKLE = uitextarea(app.UIFigure);
            app.FARKLE.Editable = 'off';
            app.FARKLE.FontSize = 48;
            app.FARKLE.FontWeight = 'bold';
            app.FARKLE.FontColor = [1 1 1];
            app.FARKLE.BackgroundColor = [1 0 0];
            app.FARKLE.Visible = 'off';
            app.FARKLE.Position = [77 223 281 85];
            app.FARKLE.Value = {'FARKLE!'};

            % Create HOTDICE
            app.HOTDICE = uitextarea(app.UIFigure);
            app.HOTDICE.Editable = 'off';
            app.HOTDICE.FontSize = 48;
            app.HOTDICE.FontWeight = 'bold';
            app.HOTDICE.FontColor = [1 0.4118 0.1608];
            app.HOTDICE.Visible = 'off';
            app.HOTDICE.Position = [77 223 281 85];
            app.HOTDICE.Value = {'HOT DICE!'};

            % Create PLAYER1
            app.PLAYER1 = uitextarea(app.UIFigure);
            app.PLAYER1.Editable = 'off';
            app.PLAYER1.HorizontalAlignment = 'center';
            app.PLAYER1.FontSize = 20;
            app.PLAYER1.FontWeight = 'bold';
            app.PLAYER1.FontColor = [0.9412 0.9412 0.9412];
            app.PLAYER1.BackgroundColor = [0.5529 0.6824 0.7686];
            app.PLAYER1.Visible = 'off';
            app.PLAYER1.Position = [310 22 121 36];
            app.PLAYER1.Value = {'PLAYER 1'};

            % Create PLAYER2
            app.PLAYER2 = uitextarea(app.UIFigure);
            app.PLAYER2.Editable = 'off';
            app.PLAYER2.HorizontalAlignment = 'center';
            app.PLAYER2.FontSize = 20;
            app.PLAYER2.FontWeight = 'bold';
            app.PLAYER2.FontColor = [0.9412 0.9412 0.9412];
            app.PLAYER2.BackgroundColor = [0.549 0.6784 0.7686];
            app.PLAYER2.Visible = 'off';
            app.PLAYER2.Position = [310 22 121 36];
            app.PLAYER2.Value = {'PLAYER 2'};

            % Create Win
            app.Win = uiimage(app.UIFigure);
            app.Win.Visible = 'off';
            app.Win.Position = [1 1 640 480];
            app.Win.ImageSource = fullfile(pathToMLAPP, 'win.png');

            % Create Lose
            app.Lose = uiimage(app.UIFigure);
            app.Lose.Visible = 'off';
            app.Lose.Position = [1 1 640 480];
            app.Lose.ImageSource = fullfile(pathToMLAPP, 'lose.png');

            % Create StartanewgameButton
            app.StartanewgameButton = uibutton(app.UIFigure, 'push');
            app.StartanewgameButton.ButtonPushedFcn = createCallbackFcn(app, @StartanewgameButtonPushed, true);
            app.StartanewgameButton.Enable = 'off';
            app.StartanewgameButton.Visible = 'off';
            app.StartanewgameButton.Position = [265 151 113 23];
            app.StartanewgameButton.Text = 'Start a new game!';

            % Create Status
            app.Status = uitextarea(app.UIFigure);
            app.Status.Editable = 'off';
            app.Status.HorizontalAlignment = 'center';
            app.Status.Position = [310 417 121 24];
            app.Status.Value = {'Start Game!'};

            % Create menu
            app.menu = uiimage(app.UIFigure);
            app.menu.ScaleMethod = 'scaleup';
            app.menu.VerticalAlignment = 'top';
            app.menu.Position = [2 1 640 480];
            app.menu.ImageSource = fullfile(pathToMLAPP, 'menu.png');

            % Create RulesButton
            app.RulesButton = uibutton(app.UIFigure, 'push');
            app.RulesButton.ButtonPushedFcn = createCallbackFcn(app, @RulesButtonPushed, true);
            app.RulesButton.Position = [84 418 58 23];
            app.RulesButton.Text = 'Rules';

            % Create StartButton
            app.StartButton = uibutton(app.UIFigure, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.BackgroundColor = [0.5451 0.7216 0.3176];
            app.StartButton.Position = [271 189 100 23];
            app.StartButton.Text = 'Start';

            % Create Rules
            app.Rules = uiimage(app.UIFigure);
            app.Rules.Visible = 'off';
            app.Rules.Position = [1 1 640 480];
            app.Rules.ImageSource = fullfile(pathToMLAPP, 'RULES.png');

            % Create CloseButton
            app.CloseButton = uibutton(app.UIFigure, 'push');
            app.CloseButton.ButtonPushedFcn = createCallbackFcn(app, @CloseButtonPushed, true);
            app.CloseButton.Enable = 'off';
            app.CloseButton.Visible = 'off';
            app.CloseButton.Position = [271 33 100 23];
            app.CloseButton.Text = 'Close';

            % Create PlayerSelection
            app.PlayerSelection = uibuttongroup(app.UIFigure);
            app.PlayerSelection.SelectionChangedFcn = createCallbackFcn(app, @PlayerSelectionSelectionChanged, true);
            app.PlayerSelection.BackgroundColor = [0.902 0.902 0.902];
            app.PlayerSelection.Position = [271 217 100 43];

            % Create Player1Button
            app.Player1Button = uiradiobutton(app.PlayerSelection);
            app.Player1Button.Text = 'Player 1';
            app.Player1Button.Position = [11 20 65 22];
            app.Player1Button.Value = true;

            % Create Player2Button
            app.Player2Button = uiradiobutton(app.PlayerSelection);
            app.Player2Button.Text = 'Player 2';
            app.Player2Button.Position = [11 1 65 22];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = Dice_Game_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end