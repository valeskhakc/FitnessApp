%% ════════════════════════════════════════════════════════════════════
%% OPTIMIZED FITNESS TRACKER DASHBOARD - PASTE AFTER MODEL TRAINING
%% ════════════════════════════════════════════════════════════════════
%% Prerequisites: You must have these variables already defined:
%%   - model (TreeBagger)
%%   - recommendationModel (fitlm)
%%   - featNames (cell array)
%%   - Fs, windowSec
%%   - activities = {'walking','running','sitting','cycling'}
%% ════════════════════════════════════════════════════════════════════

%% USER CONFIGURATION - MODIFY THESE VALUES
userWeight = 70;              % User weight in kg
targetDuration = 30;          % Target exercise duration in minutes
moderateMET = 5.0;            % MET value for moderate intensity exercise
duration = 60;                % Simulation duration in seconds
refreshRate = 0.1;            % Update rate in seconds

%% SETUP - Calculate target calories and initialize variables
targetCalories = (moderateMET * 3.5 * userWeight / 200) * targetDuration;
fprintf('Target calories calculated based on weight (%d kg): %.0f kcal\n', userWeight, targetCalories);

% Fitness tracking variables
metValues = struct('walking',3.5,'running',7.5,'sitting',1.3,'cycling',6.8);
totalCalories = 0; 
totalSteps = 0; 
heartRate = 75; 
baselineHR = 70;
breathingRate = 20;
activitySequence = {'walking','running','sitting','cycling'};
activityIndex = 1; 
windowSize = windowSec * Fs;
buffer = zeros(windowSize,3); 
prevPred = "";

% Recommendation system variables
recommendationGenerated = false;
recommendationAccepted = false;
currentRecommendation = struct('Activity', '', 'Duration', 0, 'Calories', 0);

%% CREATE DASHBOARD - Optimized layout
fig = figure('Name','💪 Fitness Tracker Pro - Live Dashboard',...
    'Color',[0.95 0.95 0.98],'Position',[50 50 1600 900]);
set(fig, 'CloseRequestFcn', @(src,evt)setappdata(src,'Closed',true));
setappdata(fig,'Closed',false);

% Store variables in figure's application data for callback access
setappdata(fig, 'targetCalories', targetCalories);
setappdata(fig, 'totalCalories', totalCalories);
setappdata(fig, 'breathingRate', breathingRate);
setappdata(fig, 'heartRate', heartRate);
setappdata(fig, 'userWeight', userWeight);
setappdata(fig, 'recommendationModel', recommendationModel);
setappdata(fig, 'currentRecommendation', currentRecommendation);
setappdata(fig, 'recommendationGenerated', recommendationGenerated);
setappdata(fig, 'recommendationAccepted', recommendationAccepted);

%% LEFT PANELS - Activity tracking visualizations

% Top left - Live Accelerometer
subplot('Position', [0.05 0.55 0.55 0.40]);
ax1 = gca;
hold(ax1, 'on');
initX = 1:windowSize;
initY = nan(windowSize, 1);
hPlot(1) = plot(ax1, initX, initY, 'Color', [1 0.2 0.4], 'LineWidth', 3);
hPlot(2) = plot(ax1, initX, initY, 'Color', [0.2 1 0.4], 'LineWidth', 3);
hPlot(3) = plot(ax1, initX, initY, 'Color', [0.2 0.6 1], 'LineWidth', 3);
hold(ax1, 'off');
legend('X','Y','Z', 'Location', 'northeast', 'FontSize', 12);
title(ax1,'🎯 Live Accelerometer', 'FontSize', 16, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.3]);
ylim([-2 2]); grid on;
xlabel('Sample', 'FontWeight', 'bold', 'FontSize', 12); 
ylabel('Acceleration (m/s²)', 'FontWeight', 'bold', 'FontSize', 12);
ax1.Color = [0.98 0.98 1];
ax1.GridColor = [0.7 0.7 0.9];
ax1.GridAlpha = 0.4;

% Bottom left - Activity Prediction Confidence
subplot('Position', [0.05 0.08 0.55 0.40]);
ax2 = gca;
hBar = bar(ax2, zeros(1,numel(activities)));
hBar.FaceColor = 'flat';
hBar.CData = [0.4 0.8 1; 1 0.3 0.5; 0.5 1 0.6; 1 0.7 0.2];
xticklabels(ax2, activities);
ylim(ax2,[0 1]);
title('📊 Activity Prediction Confidence', 'FontSize', 16, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.3]);
ylabel('Probability', 'FontWeight', 'bold', 'FontSize', 12);
grid on;
ax2.Color = [0.98 0.98 1];
ax2.GridColor = [0.7 0.7 0.9];
ax2.GridAlpha = 0.4;
ax2.FontSize = 11;

%% RIGHT PANELS - Optimized spacing for readability

% Live Metrics (top 25% - more space)
subplot('Position', [0.65 0.65 0.32 0.25]);
ax3 = gca;
axis(ax3,[0 10 0 10]); axis off;
metricsText = text(0, 10, 'Initializing...', 'FontSize', 13, 'FontWeight', 'bold',...
    'VerticalAlignment', 'top', 'Parent', ax3, 'Color', [0.1 0.1 0.3],...
    'HorizontalAlignment', 'left');

% Recommendations (middle 35% - BIGGER for expanded content)
subplot('Position', [0.65 0.25 0.32 0.35]);
ax4 = gca;
axis(ax4,[0 10 0 10]); axis off;
recText = text(0, 10, sprintf(['🎯 RECOMMENDATIONS\n' ...
    '━━━━━━━━━━━━━\n' ...
    'Target: %.0f kcal\n' ...
    '(Based on %d kg)\n' ...
    'Status: Ready\n\n' ...
    'Click Generate!'], targetCalories, userWeight), ...
    'FontSize', 13, 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
    'Parent', ax4, 'Color', [0.25 0.41 0.88], 'HorizontalAlignment', 'left');

% Store UI handles
setappdata(fig, 'recText', recText);

%% BUTTONS - Smaller to avoid blocking recommendations

% Generate Recommendation Button (6% height - SMALLER)
btnGenerate = uicontrol('Style', 'pushbutton', 'String', '✨ Generate Recommendations',...
    'Units', 'normalized', 'Position', [0.67 0.17 0.28 0.06],...
    'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', [0.6 0.8 1],...
    'ForegroundColor', [0.1 0.1 0.3], 'UserData', fig);
btnGenerate.Callback = @generateRecommendationCallback;

% Accept Button (6% height - SMALLER)
btnAccept = uicontrol('Style', 'pushbutton', 'String', '✓ Accept',...
    'Units', 'normalized', 'Position', [0.67 0.09 0.13 0.06],...
    'FontSize', 11, 'FontWeight', 'bold', 'BackgroundColor', [0.6 1 0.7],...
    'ForegroundColor', [0.1 0.3 0.1], 'Enable', 'off', 'UserData', fig);
btnAccept.Callback = @acceptRecommendationCallback;

% Modify Button (6% height - SMALLER)
btnModify = uicontrol('Style', 'pushbutton', 'String', '✎ Modify',...
    'Units', 'normalized', 'Position', [0.82 0.09 0.13 0.06],...
    'FontSize', 11, 'FontWeight', 'bold', 'BackgroundColor', [1 0.8 0.6],...
    'ForegroundColor', [0.3 0.2 0.1], 'Enable', 'off', 'UserData', fig);
btnModify.Callback = @modifyRecommendationCallback;

% Store button handles
setappdata(fig, 'btnAccept', btnAccept);
setappdata(fig, 'btnModify', btnModify);

disp('Starting stable live simulation...');
tic;

%% MAIN SIMULATION LOOP
while toc < duration
    % Exit if figure closed
    if getappdata(fig,'Closed')
        disp('Figure closed by user. Ending simulation.');
        break;
    end
    
    % Activity cycling every 15 s
    actChange = mod(floor(toc/15), numel(activitySequence)) + 1;
    if actChange ~= activityIndex
        activityIndex = actChange;
        disp(['Switched to: ', activitySequence{activityIndex}]);
    end
    currentAct = activitySequence{activityIndex};
    
    % Simulate accelerometer data
    switch currentAct
        case 'walking'
            newSample = 0.5*sin(2*pi*2*toc) + 0.05*randn; stepRate = 1.8;
        case 'running'
            newSample = 1.5*sin(2*pi*4*toc) + 0.1*randn; stepRate = 3.3;
        case 'sitting'
            newSample = 0.05*randn; stepRate = 0;
        case 'cycling'
            newSample = 1.0*sin(2*pi*3*toc) + 0.08*randn; stepRate = 2.2;
    end
    buffer = [buffer(2:end,:); [newSample 0.8*newSample+0.05*randn 0.6*newSample+0.05*randn]];
    
    % Extract features and predict
    feats = [mean(buffer), std(buffer), max(buffer), min(buffer)];
    Ttest = array2table(feats,'VariableNames',featNames(1:12));
    [predLabel, scores] = predict(model, Ttest);
    predictedActivity = string(predLabel);
    
    % Safety: check handles before updating
    if ~isvalid(ax1) || ~all(isvalid(hPlot)) || ~ishandle(fig)
        disp('Display handles invalid. Stopping simulation.');
        break;
    end
    
    % Update accelerometer plot
    set(hPlot(1), 'XData', 1:windowSize, 'YData', buffer(:,1));
    set(hPlot(2), 'XData', 1:windowSize, 'YData', buffer(:,2));
    set(hPlot(3), 'XData', 1:windowSize, 'YData', buffer(:,3));
    
    % Color-coded title based on activity
    switch char(predictedActivity)
        case 'walking'
            titleColor = [0.2 0.8 0.4];
        case 'running'
            titleColor = [1 0.2 0.4];
        case 'cycling'
            titleColor = [0.2 0.6 1];
        case 'sitting'
            titleColor = [0.6 0.6 0.6];
        otherwise
            titleColor = [0.1 0.1 0.3];
    end
    title(ax1, sprintf('🎯 Live Accelerometer — Predicted: %s | True: %s', ...
        upper(char(predictedActivity)), upper(currentAct)), 'FontSize', 16, 'Color', titleColor);
    
    % Update bar chart
    hBar.YData = scores;
    
    % Compute fitness metrics
    met = metValues.(char(predictedActivity));
    totalCalories = totalCalories + (met * 3.5 * userWeight / 200) / 60 * refreshRate;
    totalSteps = totalSteps + stepRate * refreshRate;
    heartRate = heartRate + 0.2 * ((baselineHR + 20 * (met / 3.5)) - heartRate);
    breathingRate = 15 + 10 * (met / 7.5);
    
    % Update stored values for callbacks
    setappdata(fig, 'totalCalories', totalCalories);
    setappdata(fig, 'heartRate', heartRate);
    setappdata(fig, 'breathingRate', breathingRate);
    
    % Update metrics text panel - optimized spacing
    metricsText.String = sprintf(['💪 LIVE METRICS\n\n' ...
        '🏃 Predicted: %s\n' ...
        '✓ True: %s\n' ...
        '━━━━━━━━━━━━━\n' ...
        '❤️  HR: %.1f bpm\n' ...
        '🫁 Breathing: %.0f/min\n' ...
        '🔥 Calories: %.2f kcal\n' ...
        '👣 Steps: %.0f\n' ...
        '⏱️  Time: %.1f s'], ...
        upper(char(predictedActivity)), upper(currentAct), heartRate, breathingRate, ...
        totalCalories, totalSteps, toc);
    
    if predictedActivity ~= prevPred
        disp(['Detected: ', char(predictedActivity)]);
        prevPred = predictedActivity;
    end
    
    drawnow limitrate;
    pause(refreshRate);
end

disp('Simulation complete or manually stopped.');

%% ════════════════════════════════════════════════════════════════════
%% CALLBACK FUNCTIONS - DO NOT MODIFY
%% ════════════════════════════════════════════════════════════════════

function generateRecommendationCallback(src, ~)
    fig = src.UserData;
    
    % Retrieve variables
    targetCalories = getappdata(fig, 'targetCalories');
    totalCalories = getappdata(fig, 'totalCalories');
    breathingRate = getappdata(fig, 'breathingRate');
    heartRate = getappdata(fig, 'heartRate');
    userWeight = getappdata(fig, 'userWeight');
    recommendationModel = getappdata(fig, 'recommendationModel');
    recText = getappdata(fig, 'recText');
    btnAccept = getappdata(fig, 'btnAccept');
    btnModify = getappdata(fig, 'btnModify');
    
    remainingCalories = targetCalories - totalCalories;
    
    if remainingCalories <= 0
        recText.String = sprintf(['🎯 RECOMMENDATIONS\n' ...
            '━━━━━━━━━━━━━\n\n' ...
            '✓ Target Reached!\n\n' ...
            'Current: %.0f kcal\n' ...
            'Target: %.0f kcal\n\n' ...
            '🎉 Great job!'], totalCalories, targetCalories);
        recText.Color = [0.2 0.8 0.4];
        return;
    end
    
    % Generate recommendations
    recActivities = {'walking', 'running', 'cycling'};
    recActivityCodes = [1, 2, 3];
    bestRecs = {};
    
    for i = 1:3
        testDurations = 10:5:60;
        predictedCals = zeros(length(testDurations), 1);
        
        for j = 1:length(testDurations)
            predictedCals(j) = predict(recommendationModel, ...
                [breathingRate, heartRate, recActivityCodes(i), testDurations(j)]);
        end
        
        [~, bestIdx] = min(abs(predictedCals - remainingCalories));
        bestDuration = testDurations(bestIdx);
        bestCalories = predictedCals(bestIdx);
        
        actEmojis = {'🚶', '🏃', '🚴'};
        bestRecs{end+1} = sprintf('%s %s: %dm → %.0f cal', ...
            actEmojis{i}, upper(recActivities{i}), bestDuration, bestCalories);
    end
    
    % Store recommendation
    currentRecommendation = struct('Activity', recActivities{1}, ...
        'Duration', 30, ...
        'Calories', predict(recommendationModel, [breathingRate, heartRate, 1, 30]));
    setappdata(fig, 'currentRecommendation', currentRecommendation);
    
    recText.String = sprintf(['🎯 RECOMMENDATIONS\n' ...
        '━━━━━━━━━━━━━\n\n' ...
        'Remaining: %.0f kcal\n' ...
        'HR: %.0f bpm\n' ...
        'Weight: %d kg\n' ...
        '━━━━━━━━━━━━━\n\n' ...
        '%s\n\n' ...
        '%s\n\n' ...
        '%s'], ...
        remainingCalories, heartRate, userWeight, bestRecs{1}, bestRecs{2}, bestRecs{3});
    recText.Color = [0.25 0.41 0.88]; % Royal Blue
    
    btnAccept.Enable = 'on';
    btnModify.Enable = 'on';
    
    disp('✨ Recommendation generated!');
end

function acceptRecommendationCallback(src, ~)
    fig = src.UserData;
    
    % Retrieve variables
    currentRecommendation = getappdata(fig, 'currentRecommendation');
    recText = getappdata(fig, 'recText');
    btnAccept = getappdata(fig, 'btnAccept');
    btnModify = getappdata(fig, 'btnModify');
    
    recText.String = sprintf(['✓ ACCEPTED!\n' ...
        '━━━━━━━━━━━━━\n\n' ...
        '🏃 Activity: %s\n\n' ...
        '⏱️  Duration: %d min\n\n' ...
        '🔥 Expected: %.0f kcal\n\n' ...
        '🎉 Ready to start!'], ...
        upper(currentRecommendation.Activity), ...
        currentRecommendation.Duration, ...
        currentRecommendation.Calories);
    recText.Color = [0.2 0.8 0.4];
    
    btnAccept.Enable = 'off';
    btnModify.Enable = 'off';
    
    setappdata(fig, 'recommendationAccepted', true);
    
    disp('✓ Recommendation accepted!');
end

function modifyRecommendationCallback(src, ~)
    fig = src.UserData;
    
    % Retrieve variables
    targetCalories = getappdata(fig, 'targetCalories');
    totalCalories = getappdata(fig, 'totalCalories');
    breathingRate = getappdata(fig, 'breathingRate');
    heartRate = getappdata(fig, 'heartRate');
    userWeight = getappdata(fig, 'userWeight');
    recommendationModel = getappdata(fig, 'recommendationModel');
    recText = getappdata(fig, 'recText');
    
    % Prompt for preferences
    activityOptions = {'🚶 Walking', '🏃 Running', '🚴 Cycling'};
    
    [selection, ok] = listdlg('PromptString', 'Choose your preferred activity:',...
        'SelectionMode', 'single', 'ListString', activityOptions,...
        'ListSize', [300 150], 'Name', '✨ Customize Your Workout');
    
    if ~ok
        return;
    end
    
    activityNames = {'walking', 'running', 'cycling'};
    preferredActivity = activityNames{selection};
    preferredActivityCode = selection;
    
    answer = inputdlg('Enter your preferred duration (5-120 minutes):', ...
        '⏱️ Set Duration', 1, {'30'});
    
    if isempty(answer)
        return;
    end
    
    preferredDuration = str2double(answer{1});
    
    if isnan(preferredDuration) || preferredDuration < 5 || preferredDuration > 120
        warndlg('⚠️ Duration must be between 5-120 minutes', 'Invalid Input');
        return;
    end
    
    % Recalculate
    predictedCalories = predict(recommendationModel, ...
        [breathingRate, heartRate, preferredActivityCode, preferredDuration]);
    
    remainingCalories = targetCalories - totalCalories;
    
    % Update recommendation
    currentRecommendation = struct('Activity', preferredActivity, ...
        'Duration', preferredDuration, ...
        'Calories', predictedCalories);
    setappdata(fig, 'currentRecommendation', currentRecommendation);
    
    % Provide feedback
    difference = abs(predictedCalories - remainingCalories);
    percentDiff = (difference / remainingCalories) * 100;
    
    if percentDiff <= 10
        feedback = '✓ Perfect match!';
        feedbackColor = [0.2 0.8 0.4];
    elseif predictedCalories < remainingCalories
        deficit = remainingCalories - predictedCalories;
        optimalDuration = ceil(preferredDuration * remainingCalories / predictedCalories);
        feedback = sprintf('⚠️ %.0f cal short\nTry %d min', deficit, optimalDuration);
        feedbackColor = [1 0.6 0.2];
    else
        excess = predictedCalories - remainingCalories;
        optimalDuration = floor(preferredDuration * remainingCalories / predictedCalories);
        feedback = sprintf('⚠️ %.0f cal over\nTry %d min', excess, optimalDuration);
        feedbackColor = [1 0.6 0.2];
    end
    
    actEmojis = {'🚶', '🏃', '🚴'};
    recText.String = sprintf(['✎ UPDATED\n' ...
        '━━━━━━━━━━━━━\n\n' ...
        '%s %s\n\n' ...
        '⏱️  Duration: %d min\n\n' ...
        '🔥 Predicted: %.0f kcal\n\n' ...
        '🎯 Target: %.0f kcal\n\n' ...
        '%s'], ...
        actEmojis{preferredActivityCode}, upper(preferredActivity), ...
        preferredDuration, predictedCalories, remainingCalories, feedback);
    recText.Color = feedbackColor;
    
    disp(['✎ Modified: ', preferredActivity, ' for ', num2str(preferredDuration), ' minutes']);
end

%% ════════════════════════════════════════════════════════════════════
%% END OF PASTE SECTION
%% ════════════════════════════════════════════════════════════════════
