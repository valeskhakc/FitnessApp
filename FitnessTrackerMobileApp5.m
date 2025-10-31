classdef FitnessTrackerMobileApp5 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        GridLayout                 matlab.ui.container.GridLayout
        LeftPanel                  matlab.ui.container.Panel
        ConnectionPanel            matlab.ui.container.Panel
        DataSourceDropDown         matlab.ui.control.DropDown
        DataSourceLabel            matlab.ui.control.Label
        ConnectButton              matlab.ui.control.Button
        DisconnectButton           matlab.ui.control.Button
        ConnectionStatusLabel      matlab.ui.control.Label
        ConnectionStatusValue      matlab.ui.control.Label
        ControlPanel               matlab.ui.container.Panel
        StartButton                matlab.ui.control.Button
        StopButton                 matlab.ui.control.Button
        ResetButton                matlab.ui.control.Button
        PlaybackSpeedLabel         matlab.ui.control.Label
        PlaybackSpeedSlider        matlab.ui.control.Slider
        PlaybackSpeedValue         matlab.ui.control.Label
        SettingsPanel              matlab.ui.container.Panel
        WeightKgEditFieldLabel     matlab.ui.control.Label
        WeightKgEditField          matlab.ui.control.NumericEditField
        SamplingRateLabel          matlab.ui.control.Label
        SamplingRateValue          matlab.ui.control.Label
        MetricsPanel               matlab.ui.container.Panel
        CurrentActivityLabel       matlab.ui.control.Label
        CurrentActivityValue       matlab.ui.control.Label
        TrueActivityLabel          matlab.ui.control.Label
        TrueActivityValue          matlab.ui.control.Label
        AccuracyLabel              matlab.ui.control.Label
        AccuracyValue              matlab.ui.control.Label
        HeartRateLabel             matlab.ui.control.Label
        HeartRateValue             matlab.ui.control.Label
        CaloriesLabel              matlab.ui.control.Label
        CaloriesValue              matlab.ui.control.Label
        StepsLabel                 matlab.ui.control.Label
        StepsValue                 matlab.ui.control.Label
        TimeLabel                  matlab.ui.control.Label
        TimeValue                  matlab.ui.control.Label
        RightPanel                 matlab.ui.container.Panel
        TabGroup                   matlab.ui.container.TabGroup
        AccelerometerTab           matlab.ui.container.Tab
        AccelAxes                  matlab.ui.control.UIAxes
        PredictionTab              matlab.ui.container.Tab
        PredictionAxes             matlab.ui.control.UIAxes
        HistoryTab                 matlab.ui.container.Tab
        HistoryAxes                matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        Timer                      % Timer for real-time updates
        IsRunning = false          % Simulation state
        
        % Mobile device connection
        MobileDev                  % mobiledev object
        IsConnected = false        % Connection state
        DataSource = 'Simulated'   % 'Mobile' or 'Simulated'
        
        % Model and parameters
        Model                      % Trained TreeBagger model
        FeatNames                  % Feature names
        Fs = 10                    % Sampling frequency
        WindowSec = 5              % Window size in seconds
        
        % Pre-recorded data for simulation
        RecordedData               % Full dataset with labels
        RecordedTime               % Time vector
        RecordedLabels             % True activity labels
        DataIndex = 1              % Current position in dataset
        
        % Real-time data
        Buffer                     % Accelerometer data buffer
        WindowSize                 % Buffer size
        LastLogIndex = 0           % Track last read position for mobile
        
        % Metrics
        TotalCalories = 0
        TotalSteps = 0
        HeartRate = 75
        BaselineHR = 70
        StartTime
        ElapsedTime = 0
        
        % Activity tracking
        PredictedActivity = ''
        TrueActivity = ''
        CorrectPredictions = 0
        TotalPredictions = 0
        
        % MET values (Metabolic Equivalent of Task)
        MetValues = struct('walking',3.5,'running',7.5,'sitting',1.3,'cycling',6.8)
        
        % History tracking
        TimeHistory = []
        CaloriesHistory = []
        StepsHistory = []
        HeartRateHistory = []
        PredictionHistory = []
        TrueHistory = []
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Initialize the app
            app.StopButton.Enable = 'off';
            app.ResetButton.Enable = 'on';
            app.DisconnectButton.Enable = 'off';
            
            % Generate example data and train model
            generateExampleData(app);
            trainModel(app);
            
            % Initialize buffer
            app.WindowSize = app.WindowSec * app.Fs;
            app.Buffer = zeros(app.WindowSize, 3);
            
            % Setup axes
            setupAxes(app);
            
            % Update playback speed display
            app.PlaybackSpeedValue.Text = sprintf('%.1fx', app.PlaybackSpeedSlider.Value);
            
            % Update connection status
            updateConnectionStatus(app);
            
            % Display initial metrics
            updateMetricsDisplay(app);
        end

        % Data source dropdown changed
        function DataSourceDropDownValueChanged(app, event)
            app.DataSource = app.DataSourceDropDown.Value;
            
            % Update UI based on data source
            if strcmp(app.DataSource, 'Mobile')
                app.PlaybackSpeedSlider.Enable = 'off';
                app.PlaybackSpeedLabel.Enable = 'off';
                app.PlaybackSpeedValue.Enable = 'off';
            else
                app.PlaybackSpeedSlider.Enable = 'on';
                app.PlaybackSpeedLabel.Enable = 'on';
                app.PlaybackSpeedValue.Enable = 'on';
            end
        end

        % Connect to mobile device
        function ConnectButtonPushed(app, event)
            try
                app.ConnectionStatusValue.Text = 'Connecting...';
                app.ConnectionStatusValue.FontColor = [0.8 0.6 0];
                drawnow;
                
                % Create mobiledev object
                app.MobileDev = mobiledev;
                
                % Check connection
                if app.MobileDev.Connected
                    % Enable accelerometer
                    app.MobileDev.AccelerationSensorEnabled = 1;
                    
                    % Get actual sampling rate
                    app.Fs = app.MobileDev.SampleRate;
                    app.SamplingRateValue.Text = sprintf('%.1f Hz', app.Fs);
                    
                    % Update buffer size based on actual sampling rate
                    app.WindowSize = round(app.WindowSec * app.Fs);
                    app.Buffer = zeros(app.WindowSize, 3);
                    
                    app.IsConnected = true;
                    app.DataSource = 'Mobile';
                    app.DataSourceDropDown.Value = 'Mobile';
                    
                    app.ConnectButton.Enable = 'off';
                    app.DisconnectButton.Enable = 'on';
                    app.DataSourceDropDown.Enable = 'off';
                    
                    updateConnectionStatus(app);
                    
                    uialert(app.UIFigure, ...
                        'Successfully connected to mobile device!', ...
                        'Connection Success', 'Icon', 'success');
                else
                    error('Connection failed');
                end
                
            catch ME
                app.IsConnected = false;
                updateConnectionStatus(app);
                uialert(app.UIFigure, ...
                    sprintf('Failed to connect: %s\n\nMake sure MATLAB Mobile is running and logged in.', ME.message), ...
                    'Connection Error', 'Icon', 'error');
            end
        end

        % Disconnect from mobile device
        function DisconnectButtonPushed(app, event)
            try
                if ~isempty(app.MobileDev)
                    % Disable sensors
                    app.MobileDev.AccelerationSensorEnabled = 0;
                    
                    % Clear the object
                    clear app.MobileDev;
                    app.MobileDev = [];
                end
                
                app.IsConnected = false;
                app.ConnectButton.Enable = 'on';
                app.DisconnectButton.Enable = 'off';
                app.DataSourceDropDown.Enable = 'on';
                
                % Reset to default sampling rate
                app.Fs = 10;
                app.SamplingRateValue.Text = '10.0 Hz';
                app.WindowSize = app.WindowSec * app.Fs;
                app.Buffer = zeros(app.WindowSize, 3);
                
                updateConnectionStatus(app);
                
            catch ME
                warning('Error disconnecting: %s', ME.message);
            end
        end

        % Start button
        function StartButtonPushed(app, event)
            if ~app.IsRunning
                % Check if mobile source selected but not connected
                if strcmp(app.DataSource, 'Mobile') && ~app.IsConnected
                    uialert(app.UIFigure, ...
                        'Please connect to mobile device first!', ...
                        'Not Connected', 'Icon', 'warning');
                    return;
                end
                
                app.IsRunning = true;
                app.StartButton.Enable = 'off';
                app.StopButton.Enable = 'on';
                app.ResetButton.Enable = 'off';
                app.ConnectButton.Enable = 'off';
                app.DisconnectButton.Enable = 'off';
                app.DataSourceDropDown.Enable = 'off';
                
                % Start logging if using mobile
                if strcmp(app.DataSource, 'Mobile') && ~isempty(app.MobileDev)
                    app.MobileDev.Logging = 1;
                    app.LastLogIndex = 0;
                end
                
                % Reset start time
                app.StartTime = tic;
                
                % Create and start timer (update every 0.1 seconds)
                app.Timer = timer('ExecutionMode', 'fixedRate', ...
                                  'Period', 0.1, ...
                                  'TimerFcn', @(~,~)updateSimulation(app));
                start(app.Timer);
            end
        end

        % Stop button
        function StopButtonPushed(app, event)
            stopSimulation(app);
        end

        % Reset button
        function ResetButtonPushed(app, event)
            % Reset all metrics
            app.TotalCalories = 0;
            app.TotalSteps = 0;
            app.HeartRate = 75;
            app.ElapsedTime = 0;
            app.DataIndex = 1;
            app.Buffer = zeros(app.WindowSize, 3);
            app.CorrectPredictions = 0;
            app.TotalPredictions = 0;
            app.LastLogIndex = 0;
            
            % Clear history
            app.TimeHistory = [];
            app.CaloriesHistory = [];
            app.StepsHistory = [];
            app.HeartRateHistory = [];
            app.PredictionHistory = [];
            app.TrueHistory = [];
            
            % Update displays
            updateMetricsDisplay(app);
            setupAxes(app);
        end

        % Playback speed slider
        function PlaybackSpeedSliderValueChanged(app, event)
            value = app.PlaybackSpeedSlider.Value;
            app.PlaybackSpeedValue.Text = sprintf('%.1fx', value);
        end
    end
    

    % Private methods
    methods (Access = private)
        
        function updateConnectionStatus(app)
            if app.IsConnected
                app.ConnectionStatusValue.Text = 'Connected';
                app.ConnectionStatusValue.FontColor = [0 0.6 0];
            else
                app.ConnectionStatusValue.Text = 'Not Connected';
                app.ConnectionStatusValue.FontColor = [0.8 0 0];
            end
        end
        
        function generateExampleData(app)
            % Generate synthetic data for simulation mode
            t = (0:1/app.Fs:300)';
            N = numel(t);
            activities = {'walking','running','sitting','cycling'};
            labels = strings(N,1);
            accX = zeros(N,1);
            accY = zeros(N,1);
            accZ = zeros(N,1);
            
            for i = 1:N
                actIndex = mod(floor(i/(app.Fs*45)),4) + 1;
                currentAct = activities{actIndex};
                
                switch currentAct
                    case 'walking'
                        base = 0.5*sin(2*pi*2*t(i)) + 0.05*randn;
                    case 'running'
                        base = 1.5*sin(2*pi*4*t(i)) + 0.1*randn;
                    case 'sitting'
                        base = 0.05*randn;
                    case 'cycling'
                        base = 1.0*sin(2*pi*3*t(i)) + 0.08*randn;
                end
                
                accX(i) = base;
                accY(i) = 0.8*base + 0.05*randn;
                accZ(i) = 0.6*base + 0.05*randn;
                labels(i) = currentAct;
            end
            
            % Store the recorded data
            app.RecordedData = [accX, accY, accZ];
            app.RecordedTime = t;
            app.RecordedLabels = labels;
        end
        
        function trainModel(app)
            % Extract features from the example data
            winSize = app.WindowSec * app.Fs;
            N = size(app.RecordedData, 1);
            numWins = floor(N/winSize);
            featMat = [];
            labelVec = [];
            
            for i = 1:numWins
                idx = (i-1)*winSize + 1 : i*winSize;
                segX = app.RecordedData(idx, 1);
                segY = app.RecordedData(idx, 2);
                segZ = app.RecordedData(idx, 3);
                
                feat = [mean(segX) mean(segY) mean(segZ) ...
                       std(segX) std(segY) std(segZ) ...
                       max(segX) max(segY) max(segZ) ...
                       min(segX) min(segY) min(segZ)];
                
                featMat = [featMat; feat];
                labelVec = [labelVec; mode(categorical(app.RecordedLabels(idx)))];
            end
            
            app.FeatNames = {'meanX','meanY','meanZ','stdX','stdY','stdZ',...
                            'maxX','maxY','maxZ','minX','minY','minZ'};
            Ttrain = array2table(featMat,'VariableNames',app.FeatNames);
            Ttrain.Activity = labelVec;
            
            % Train model
            rng(1);
            app.Model = TreeBagger(40,Ttrain(:,1:end-1),Ttrain.Activity);
        end
        
        function setupAxes(app)
            % Setup accelerometer plot
            cla(app.AccelAxes);
            hold(app.AccelAxes, 'on');
            plot(app.AccelAxes, 1:app.WindowSize, nan(app.WindowSize,1), 'r-', 'LineWidth', 1.5);
            plot(app.AccelAxes, 1:app.WindowSize, nan(app.WindowSize,1), 'g-', 'LineWidth', 1.5);
            plot(app.AccelAxes, 1:app.WindowSize, nan(app.WindowSize,1), 'b-', 'LineWidth', 1.5);
            legend(app.AccelAxes, {'X','Y','Z'}, 'Location', 'northeast');
            title(app.AccelAxes, 'Live Accelerometer Data');
            xlabel(app.AccelAxes, 'Sample');
            ylabel(app.AccelAxes, 'Acceleration (m/s²)');
            ylim(app.AccelAxes, [-15 15]);
            grid(app.AccelAxes, 'on');
            hold(app.AccelAxes, 'off');
            
            % Setup prediction bar chart
            cla(app.PredictionAxes);
            bar(app.PredictionAxes, zeros(1,4));
            set(app.PredictionAxes, 'XTickLabel', {'walking','running','sitting','cycling'});
            ylim(app.PredictionAxes, [0 1]);
            title(app.PredictionAxes, 'Activity Prediction Confidence');
            ylabel(app.PredictionAxes, 'Probability');
            grid(app.PredictionAxes, 'on');
            
            % Setup history plot
            cla(app.HistoryAxes);
            hold(app.HistoryAxes, 'on');
            yyaxis(app.HistoryAxes, 'left');
            plot(app.HistoryAxes, 0, 0, 'r-', 'LineWidth', 2);
            ylabel(app.HistoryAxes, 'Calories (kcal)');
            yyaxis(app.HistoryAxes, 'right');
            plot(app.HistoryAxes, 0, 0, 'b-', 'LineWidth', 2);
            ylabel(app.HistoryAxes, 'Heart Rate (bpm)');
            title(app.HistoryAxes, 'Metrics Over Time');
            xlabel(app.HistoryAxes, 'Time (s)');
            grid(app.HistoryAxes, 'on');
            legend(app.HistoryAxes, {'Calories','Heart Rate'}, 'Location', 'northwest');
            hold(app.HistoryAxes, 'off');
        end
        
        function updateSimulation(app)
            try
                % Get new data based on source
                if strcmp(app.DataSource, 'Mobile')
                    newSample = getMobileData(app);
                    if isempty(newSample)
                        return; % No new data available
                    end
                    app.TrueActivity = ''; % Unknown for real data
                else
                    % Simulated data
                    if app.DataIndex > size(app.RecordedData, 1)
                        stopSimulation(app);
                        return;
                    end
                    
                    playbackSpeed = app.PlaybackSpeedSlider.Value;
                    currentIdx = min(app.DataIndex, size(app.RecordedData, 1));
                    newSample = app.RecordedData(currentIdx, :);
                    app.TrueActivity = app.RecordedLabels(currentIdx);
                    app.DataIndex = app.DataIndex + max(1, round(playbackSpeed));
                    app.ElapsedTime = app.ElapsedTime + 0.1 * playbackSpeed;
                end
                
                % Update buffer
                app.Buffer = [app.Buffer(2:end,:); newSample];
                
                % Update elapsed time for mobile
                if strcmp(app.DataSource, 'Mobile')
                    app.ElapsedTime = toc(app.StartTime);
                end
                
                % Only make predictions when we have a full buffer
                if all(app.Buffer(1,:) ~= 0)
                    % Extract features and predict
                    feats = [mean(app.Buffer), std(app.Buffer), max(app.Buffer), min(app.Buffer)];
                    Ttest = array2table(feats,'VariableNames',app.FeatNames);
                    [predLabel, scores] = predict(app.Model, Ttest);
                    app.PredictedActivity = string(predLabel);
                    
                    % Calculate accuracy (only for simulated data)
                    if strcmp(app.DataSource, 'Simulated')
                        app.TotalPredictions = app.TotalPredictions + 1;
                        if strcmp(app.PredictedActivity, app.TrueActivity)
                            app.CorrectPredictions = app.CorrectPredictions + 1;
                        end
                    end
                    
                    % Determine step rate
                    if strcmp(app.DataSource, 'Mobile') || isempty(app.TrueActivity)
                        % Use predicted activity for step rate
                        activityForSteps = app.PredictedActivity;
                    else
                        % Use true activity for step rate
                        activityForSteps = app.TrueActivity;
                    end
                    
                    switch char(activityForSteps)
                        case 'walking'
                            stepRate = 1.8;
                        case 'running'
                            stepRate = 3.3;
                        case 'sitting'
                            stepRate = 0;
                        case 'cycling'
                            stepRate = 2.2;
                        otherwise
                            stepRate = 0;
                    end
                    
                    % Update metrics based on PREDICTED activity
                    met = app.MetValues.(char(app.PredictedActivity));
                    
                    if strcmp(app.DataSource, 'Simulated')
                        playbackSpeed = app.PlaybackSpeedSlider.Value;
                    else
                        playbackSpeed = 1;
                    end
                    
                    app.TotalCalories = app.TotalCalories + (met * 3.5 * app.WeightKgEditField.Value / 200) / 60 * 0.1 * playbackSpeed;
                    app.TotalSteps = app.TotalSteps + stepRate * 0.1 * playbackSpeed;
                    app.HeartRate = app.HeartRate + 0.2 * ((app.BaselineHR + 20 * (met / 3.5)) - app.HeartRate);
                    
                    % Update history
                    app.TimeHistory = [app.TimeHistory; app.ElapsedTime];
                    app.CaloriesHistory = [app.CaloriesHistory; app.TotalCalories];
                    app.StepsHistory = [app.StepsHistory; app.TotalSteps];
                    app.HeartRateHistory = [app.HeartRateHistory; app.HeartRate];
                    app.PredictionHistory = [app.PredictionHistory; app.PredictedActivity];
                    
                    % Update visualizations
                    updatePlots(app, scores);
                end
                
                % Update metrics display
                updateMetricsDisplay(app);
                
            catch ME
                warning('Error in simulation update: %s', ME.message);
                stopSimulation(app);
            end
        end
        
        function newSample = getMobileData(app)
            % Get data from mobile device
            newSample = [];
            
            try
                if ~isempty(app.MobileDev) && app.MobileDev.Logging
                    % Get logged acceleration data
                    [accel, ~] = accellog(app.MobileDev);
                    
                    % Check if new data is available
                    numSamples = size(accel, 1);
                    if numSamples > app.LastLogIndex
                        % Get the most recent sample
                        newSample = accel(end, :);
                        app.LastLogIndex = numSamples;
                    end
                end
            catch ME
                warning('Error reading mobile data: %s', ME.message);
            end
        end
        
        function updatePlots(app, scores)
            % Update accelerometer plot
            lines = findobj(app.AccelAxes, 'Type', 'Line');
            if numel(lines) == 3
                set(lines(3), 'YData', app.Buffer(:,1));
                set(lines(2), 'YData', app.Buffer(:,2));
                set(lines(1), 'YData', app.Buffer(:,3));
            end
            
            % Color title based on data source and accuracy
            if strcmp(app.DataSource, 'Mobile')
                titleText = sprintf('Live Accelerometer — Predicted: %s | Source: MOBILE DEVICE', ...
                    app.PredictedActivity);
                titleColor = [0 0.4 0.8]; % Blue for mobile
            else
                if strcmp(app.PredictedActivity, app.TrueActivity)
                    titleColor = [0 0.6 0]; % Green for correct
                else
                    titleColor = [0.8 0 0]; % Red for incorrect
                end
                titleText = sprintf('Live Accelerometer — Predicted: %s | True: %s', ...
                    app.PredictedActivity, app.TrueActivity);
            end
            title(app.AccelAxes, titleText, 'Color', titleColor);
            
            % Update prediction bar chart
            bars = findobj(app.PredictionAxes, 'Type', 'Bar');
            if ~isempty(bars)
                set(bars, 'YData', scores);
            end
            
            % Update history plot
            if ~isempty(app.TimeHistory)
                lines = findobj(app.HistoryAxes, 'Type', 'Line');
                if numel(lines) == 2
                    yyaxis(app.HistoryAxes, 'left');
                    set(lines(2), 'XData', app.TimeHistory, 'YData', app.CaloriesHistory);
                    xlim(app.HistoryAxes, [0 max(app.TimeHistory)+1]);
                    
                    yyaxis(app.HistoryAxes, 'right');
                    set(lines(1), 'XData', app.TimeHistory, 'YData', app.HeartRateHistory);
                end
            end
        end
        
        function updateMetricsDisplay(app)
            % Update predicted activity with color coding
            app.CurrentActivityValue.Text = app.PredictedActivity;
            switch char(app.PredictedActivity)
                case 'running'
                    app.CurrentActivityValue.FontColor = [0.8 0 0];
                case 'walking'
                    app.CurrentActivityValue.FontColor = [0 0.6 0];
                case 'cycling'
                    app.CurrentActivityValue.FontColor = [0 0.4 0.8];
                case 'sitting'
                    app.CurrentActivityValue.FontColor = [0.5 0.5 0.5];
                otherwise
                    app.CurrentActivityValue.FontColor = [0 0 0];
            end
            
            % Update true activity (hide for mobile)
            if strcmp(app.DataSource, 'Mobile')
                app.TrueActivityLabel.Visible = 'off';
                app.TrueActivityValue.Visible = 'off';
                app.AccuracyLabel.Visible = 'off';
                app.AccuracyValue.Visible = 'off';
            else
                app.TrueActivityLabel.Visible = 'on';
                app.TrueActivityValue.Visible = 'on';
                app.AccuracyLabel.Visible = 'on';
                app.AccuracyValue.Visible = 'on';
                
                app.TrueActivityValue.Text = app.TrueActivity;
                switch char(app.TrueActivity)
                    case 'running'
                        app.TrueActivityValue.FontColor = [0.8 0 0];
                    case 'walking'
                        app.TrueActivityValue.FontColor = [0 0.6 0];
                    case 'cycling'
                        app.TrueActivityValue.FontColor = [0 0.4 0.8];
                    case 'sitting'
                        app.TrueActivityValue.FontColor = [0.5 0.5 0.5];
                    otherwise
                        app.TrueActivityValue.FontColor = [0 0 0];
                end
                
                % Update accuracy
                if app.TotalPredictions > 0
                    accuracy = 100 * app.CorrectPredictions / app.TotalPredictions;
                    app.AccuracyValue.Text = sprintf('%.1f%%', accuracy);
                    if accuracy >= 90
                        app.AccuracyValue.FontColor = [0 0.6 0];
                    elseif accuracy >= 70
                        app.AccuracyValue.FontColor = [0.8 0.6 0];
                    else
                        app.AccuracyValue.FontColor = [0.8 0 0];
                    end
                else
                    app.AccuracyValue.Text = '--';
                end
            end
            
            % Update other metrics
            app.HeartRateValue.Text = sprintf('%.1f bpm', app.HeartRate);
            app.CaloriesValue.Text = sprintf('%.2f kcal', app.TotalCalories);
            app.StepsValue.Text = sprintf('%.0f', app.TotalSteps);
            app.TimeValue.Text = sprintf('%.1f s', app.ElapsedTime);
        end
        
        function stopSimulation(app)
            if app.IsRunning && ~isempty(app.Timer) && isvalid(app.Timer)
                stop(app.Timer);
                delete(app.Timer);
            end
            
            % Stop mobile logging if active
            if strcmp(app.DataSource, 'Mobile') && ~isempty(app.MobileDev)
                try
                    app.MobileDev.Logging = 0;
                catch
                    % Ignore errors if device disconnected
                end
            end
            
            app.IsRunning = false;
            app.StartButton.Enable = 'on';
            app.StopButton.Enable = 'off';
            app.ResetButton.Enable = 'on';
            app.DataSourceDropDown.Enable = 'on';
            
            if app.IsConnected
                app.DisconnectButton.Enable = 'on';
            else
                app.ConnectButton.Enable = 'on';
            end
        end
    end
    

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 750];
            app.UIFigure.Name = 'Fitness Tracker - Mobile Integration';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x', '2x'};
            app.GridLayout.RowHeight = {'1x'};

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.FontWeight = 'bold';
            app.LeftPanel.FontSize = 14;

            % Create ConnectionPanel
            app.ConnectionPanel = uipanel(app.LeftPanel);
            app.ConnectionPanel.Title = 'Data Source';
            app.ConnectionPanel.Position = [10 600 360 130];

            % Create DataSourceLabel
            app.DataSourceLabel = uilabel(app.ConnectionPanel);
            app.DataSourceLabel.Position = [20 75 100 22];
            app.DataSourceLabel.Text = 'Source:';

            % Create DataSourceDropDown
            app.DataSourceDropDown = uidropdown(app.ConnectionPanel);
            app.DataSourceDropDown.Items = {'Simulated', 'Mobile'};
            app.DataSourceDropDown.ValueChangedFcn = createCallbackFcn(app, @DataSourceDropDownValueChanged, true);
            app.DataSourceDropDown.Position = [100 75 240 22];
            app.DataSourceDropDown.Value = 'Simulated';

            % Create ConnectButton
            app.ConnectButton = uibutton(app.ConnectionPanel, 'push');
            app.ConnectButton.ButtonPushedFcn = createCallbackFcn(app, @ConnectButtonPushed, true);
            app.ConnectButton.BackgroundColor = [0.3 0.7 0.3];
            app.ConnectButton.FontSize = 12;
            app.ConnectButton.FontWeight = 'bold';
            app.ConnectButton.Position = [20 40 150 30];
            app.ConnectButton.Text = 'Connect Mobile';

            % Create DisconnectButton
            app.DisconnectButton = uibutton(app.ConnectionPanel, 'push');
            app.DisconnectButton.ButtonPushedFcn = createCallbackFcn(app, @DisconnectButtonPushed, true);
            app.DisconnectButton.BackgroundColor = [0.8 0.4 0.4];
            app.DisconnectButton.FontSize = 12;
            app.DisconnectButton.FontWeight = 'bold';
            app.DisconnectButton.Position = [190 40 150 30];
            app.DisconnectButton.Text = 'Disconnect';

            % Create ConnectionStatusLabel
            app.ConnectionStatusLabel = uilabel(app.ConnectionPanel);
            app.ConnectionStatusLabel.Position = [20 10 60 22];
            app.ConnectionStatusLabel.Text = 'Status:';

            % Create ConnectionStatusValue
            app.ConnectionStatusValue = uilabel(app.ConnectionPanel);
            app.ConnectionStatusValue.Position = [90 10 250 22];
            app.ConnectionStatusValue.Text = 'Not Connected';
            app.ConnectionStatusValue.FontWeight = 'bold';
            app.ConnectionStatusValue.FontColor = [0.8 0 0];

            % Create ControlPanel
            app.ControlPanel = uipanel(app.LeftPanel);
            app.ControlPanel.Title = 'Playback Controls';
            app.ControlPanel.Position = [10 450 360 140];

            % Create StartButton
            app.StartButton = uibutton(app.ControlPanel, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.BackgroundColor = [0.4 0.8 0.4];
            app.StartButton.FontSize = 14;
            app.StartButton.FontWeight = 'bold';
            app.StartButton.Position = [20 65 100 40];
            app.StartButton.Text = 'Start';

            % Create StopButton
            app.StopButton = uibutton(app.ControlPanel, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.StopButton.BackgroundColor = [0.9 0.4 0.4];
            app.StopButton.FontSize = 14;
            app.StopButton.FontWeight = 'bold';
            app.StopButton.Position = [130 65 100 40];
            app.StopButton.Text = 'Stop';

            % Create ResetButton
            app.ResetButton = uibutton(app.ControlPanel, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonPushed, true);
            app.ResetButton.BackgroundColor = [0.8 0.8 0.4];
            app.ResetButton.FontSize = 14;
            app.ResetButton.FontWeight = 'bold';
            app.ResetButton.Position = [240 65 100 40];
            app.ResetButton.Text = 'Reset';

            % Create PlaybackSpeedLabel
            app.PlaybackSpeedLabel = uilabel(app.ControlPanel);
            app.PlaybackSpeedLabel.Position = [20 35 130 22];
            app.PlaybackSpeedLabel.Text = 'Playback Speed (Sim)';

            % Create PlaybackSpeedSlider
            app.PlaybackSpeedSlider = uislider(app.ControlPanel);
            app.PlaybackSpeedSlider.Limits = [0.5 5];
            app.PlaybackSpeedSlider.ValueChangedFcn = createCallbackFcn(app, @PlaybackSpeedSliderValueChanged, true);
            app.PlaybackSpeedSlider.Position = [20 20 250 3];
            app.PlaybackSpeedSlider.Value = 1;

            % Create PlaybackSpeedValue
            app.PlaybackSpeedValue = uilabel(app.ControlPanel);
            app.PlaybackSpeedValue.Position = [280 15 60 22];
            app.PlaybackSpeedValue.Text = '1.0x';

            % Create SettingsPanel
            app.SettingsPanel = uipanel(app.LeftPanel);
            app.SettingsPanel.Title = 'Settings';
            app.SettingsPanel.Position = [10 350 360 90];

            % Create WeightKgEditFieldLabel
            app.WeightKgEditFieldLabel = uilabel(app.SettingsPanel);
            app.WeightKgEditFieldLabel.HorizontalAlignment = 'right';
            app.WeightKgEditFieldLabel.Position = [20 35 80 22];
            app.WeightKgEditFieldLabel.Text = 'Weight (kg)';

            % Create WeightKgEditField
            app.WeightKgEditField = uieditfield(app.SettingsPanel, 'numeric');
            app.WeightKgEditField.Limits = [30 200];
            app.WeightKgEditField.Position = [115 35 100 22];
            app.WeightKgEditField.Value = 70;

            % Create SamplingRateLabel
            app.SamplingRateLabel = uilabel(app.SettingsPanel);
            app.SamplingRateLabel.Position = [20 10 100 22];
            app.SamplingRateLabel.Text = 'Sampling Rate:';

            % Create SamplingRateValue
            app.SamplingRateValue = uilabel(app.SettingsPanel);
            app.SamplingRateValue.Position = [125 10 100 22];
            app.SamplingRateValue.Text = '10.0 Hz';
            app.SamplingRateValue.FontWeight = 'bold';

            % Create MetricsPanel
            app.MetricsPanel = uipanel(app.LeftPanel);
            app.MetricsPanel.Title = 'Live Metrics & Accuracy';
            app.MetricsPanel.Position = [10 10 360 330];

            % Predicted Activity
            app.CurrentActivityLabel = uilabel(app.MetricsPanel);
            app.CurrentActivityLabel.FontSize = 12;
            app.CurrentActivityLabel.FontWeight = 'bold';
            app.CurrentActivityLabel.Position = [20 275 120 22];
            app.CurrentActivityLabel.Text = 'Predicted:';

            app.CurrentActivityValue = uilabel(app.MetricsPanel);
            app.CurrentActivityValue.FontSize = 16;
            app.CurrentActivityValue.FontWeight = 'bold';
            app.CurrentActivityValue.Position = [140 270 180 30];
            app.CurrentActivityValue.Text = '---';

            % True Activity
            app.TrueActivityLabel = uilabel(app.MetricsPanel);
            app.TrueActivityLabel.FontSize = 12;
            app.TrueActivityLabel.FontWeight = 'bold';
            app.TrueActivityLabel.Position = [20 235 120 22];
            app.TrueActivityLabel.Text = 'True Activity:';

            app.TrueActivityValue = uilabel(app.MetricsPanel);
            app.TrueActivityValue.FontSize = 16;
            app.TrueActivityValue.FontWeight = 'bold';
            app.TrueActivityValue.Position = [140 230 180 30];
            app.TrueActivityValue.Text = '---';

            % Accuracy
            app.AccuracyLabel = uilabel(app.MetricsPanel);
            app.AccuracyLabel.FontSize = 12;
            app.AccuracyLabel.FontWeight = 'bold';
            app.AccuracyLabel.Position = [20 195 120 22];
            app.AccuracyLabel.Text = 'Accuracy:';

            app.AccuracyValue = uilabel(app.MetricsPanel);
            app.AccuracyValue.FontSize = 18;
            app.AccuracyValue.FontWeight = 'bold';
            app.AccuracyValue.FontColor = [0 0.6 0];
            app.AccuracyValue.Position = [140 190 180 30];
            app.AccuracyValue.Text = '--';

            % Divider
            line1 = uilabel(app.MetricsPanel);
            line1.Text = '________________________________';
            line1.Position = [20 170 320 22];
            line1.FontColor = [0.7 0.7 0.7];

            % Heart Rate
            app.HeartRateLabel = uilabel(app.MetricsPanel);
            app.HeartRateLabel.FontSize = 11;
            app.HeartRateLabel.Position = [20 135 100 22];
            app.HeartRateLabel.Text = 'Heart Rate:';

            app.HeartRateValue = uilabel(app.MetricsPanel);
            app.HeartRateValue.FontSize = 18;
            app.HeartRateValue.FontWeight = 'bold';
            app.HeartRateValue.FontColor = [0.8 0 0];
            app.HeartRateValue.Position = [140 130 180 30];
            app.HeartRateValue.Text = '75.0 bpm';

            % Calories
            app.CaloriesLabel = uilabel(app.MetricsPanel);
            app.CaloriesLabel.FontSize = 11;
            app.CaloriesLabel.Position = [20 95 100 22];
            app.CaloriesLabel.Text = 'Calories Burned:';

            app.CaloriesValue = uilabel(app.MetricsPanel);
            app.CaloriesValue.FontSize = 18;
            app.CaloriesValue.FontWeight = 'bold';
            app.CaloriesValue.FontColor = [0.8 0.5 0];
            app.CaloriesValue.Position = [140 90 180 30];
            app.CaloriesValue.Text = '0.00 kcal';

            % Steps
            app.StepsLabel = uilabel(app.MetricsPanel);
            app.StepsLabel.FontSize = 11;
            app.StepsLabel.Position = [20 55 100 22];
            app.StepsLabel.Text = 'Steps:';

            app.StepsValue = uilabel(app.MetricsPanel);
            app.StepsValue.FontSize = 18;
            app.StepsValue.FontWeight = 'bold';
            app.StepsValue.FontColor = [0 0.6 0];
            app.StepsValue.Position = [140 50 180 30];
            app.StepsValue.Text = '0';

            % Time
            app.TimeLabel = uilabel(app.MetricsPanel);
            app.TimeLabel.FontSize = 11;
            app.TimeLabel.Position = [20 15 100 22];
            app.TimeLabel.Text = 'Elapsed Time:';

            app.TimeValue = uilabel(app.MetricsPanel);
            app.TimeValue.FontSize = 18;
            app.TimeValue.FontWeight = 'bold';
            app.TimeValue.FontColor = [0 0.4 0.8];
            app.TimeValue.Position = [140 10 180 30];
            app.TimeValue.Text = '0.0 s';

            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Title = 'Real-Time Visualizations';
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;
            app.RightPanel.FontWeight = 'bold';
            app.RightPanel.FontSize = 14;

            % Create TabGroup
            app.TabGroup = uitabgroup(app.RightPanel);
            app.TabGroup.Position = [10 10 760 690];

            % Create AccelerometerTab
            app.AccelerometerTab = uitab(app.TabGroup);
            app.AccelerometerTab.Title = 'Accelerometer';

            % Create AccelAxes
            app.AccelAxes = uiaxes(app.AccelerometerTab);
            app.AccelAxes.Position = [20 20 720 620];

            % Create PredictionTab
            app.PredictionTab = uitab(app.TabGroup);
            app.PredictionTab.Title = 'Prediction';

            % Create PredictionAxes
            app.PredictionAxes = uiaxes(app.PredictionTab);
            app.PredictionAxes.Position = [20 20 720 620];

            % Create HistoryTab
            app.HistoryTab = uitab(app.TabGroup);
            app.HistoryTab.Title = 'History';

            % Create HistoryAxes
            app.HistoryAxes = uiaxes(app.HistoryTab);
            app.HistoryAxes.Position = [20 20 720 620];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = FitnessTrackerMobileApp5

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

            % Stop and delete timer if running
            if ~isempty(app.Timer) && isvalid(app.Timer)
                stop(app.Timer);
                delete(app.Timer);
            end

            % Disconnect mobile device if connected
            if app.IsConnected && ~isempty(app.MobileDev)
                try
                    app.MobileDev.Logging = 0;
                    app.MobileDev.AccelerationSensorEnabled = 0;
                    clear app.MobileDev;
                catch
                    % Ignore errors during cleanup
                end
            end

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
    
    methods (Access = private)
        % Close request function
        function UIFigureCloseRequest(app, event)
            % Stop simulation before closing
            stopSimulation(app);
            delete(app);
        end
    end
end
