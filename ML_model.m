%% STABLE FITNESS TRACKER TRAINING + MODEL COMPARISON + LIVE DASHBOARD
clc; clear; close all;
disp('=== FITNESS TRACKER TRAINING AND LIVE DASHBOARD ===');

%% 1. Generate synthetic accelerometer data
Fs = 10; windowSec = 5; overlapSec = 0;
t = (0:1/Fs:300)'; 
activities = {'walking','running','sitting','cycling'};
N = numel(t); labels = strings(N,1);
accX = zeros(N,1); accY = zeros(N,1); accZ = zeros(N,1);

for i = 1:N
    actIndex = mod(floor(i/(Fs*45)),4) + 1;
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

data = timetable(seconds(t), accX, accY, accZ, categorical(labels), ...
    'VariableNames', {'accX','accY','accZ','labels'});

%% 2. Feature extraction
disp('Extracting features...');
winSize = windowSec * Fs;
numWins = floor(height(data)/winSize);
featMat = []; labelVec = [];

for i = 1:numWins
    idx = (i-1)*winSize + 1 : i*winSize;
    segment = data(idx,:);
    feat = [mean(segment.accX) mean(segment.accY) mean(segment.accZ) ...
            std(segment.accX) std(segment.accY) std(segment.accZ) ...
            max(segment.accX) max(segment.accY) max(segment.accZ) ...
            min(segment.accX) min(segment.accY) min(segment.accZ)];
    featMat = [featMat; feat];
    labelVec = [labelVec; mode(segment.labels)];
end

featNames = {'meanX','meanY','meanZ','stdX','stdY','stdZ','maxX','maxY','maxZ','minX','minY','minZ'};
Ttrain = array2table(featMat,'VariableNames',featNames);
Ttrain.Activity = labelVec;

%% 3. Split data into training and testing sets
disp('Splitting data...');
cv = cvpartition(Ttrain.Activity, 'HoldOut', 0.3);
trainData = Ttrain(training(cv), :);
testData  = Ttrain(test(cv), :);

%% 4. Train multiple models
disp('Training TreeBagger (Random Forest)...');
rng(1);
treeModel = TreeBagger(40, trainData(:,1:end-1), trainData.Activity);

disp('Training KNN model...');
knnModel = fitcknn(trainData(:,1:end-1), trainData.Activity, 'NumNeighbors', 5);

disp('Training SVM model...');
svmModel = fitcecoc(trainData(:,1:end-1), trainData.Activity);

%% 5. Evaluate models
disp('Evaluating models...');
models = {'TreeBagger','KNN','SVM'};
preds = cell(3,1);
acc = zeros(3,1);

for i = 1:3
    switch models{i}
        case 'TreeBagger'
            pred = predict(treeModel, testData(:,1:end-1));
            pred = categorical(pred);
        case 'KNN'
            pred = predict(knnModel, testData(:,1:end-1));
        case 'SVM'
            pred = predict(svmModel, testData(:,1:end-1));
    end
    preds{i} = pred;
    acc(i) = mean(pred == testData.Activity);
    fprintf('%s Accuracy: %.2f%%\n', models{i}, acc(i)*100);
end

%% 6. Confusion matrices
figure('Name','Confusion Matrices','Position',[100 100 1200 400]);
for i = 1:3
    subplot(1,3,i);
    confusionchart(testData.Activity, preds{i});
    title(sprintf('%s Confusion Matrix', models{i}));
end

%% 7. Precision, Recall, and F1-score
for i = 1:3
    cm = confusionmat(testData.Activity, preds{i});
    TP = diag(cm);
    FP = sum(cm,1)' - TP;
    FN = sum(cm,2) - TP;
    precision = TP ./ (TP + FP);
    recall = TP ./ (TP + FN);
    F1 = 2 * (precision .* recall) ./ (precision + recall);
    
    fprintf('\n=== %s Metrics ===\n', models{i});
    disp(table(categories(testData.Activity), precision, recall, F1));
end

%% 8. Accuracy comparison plot
figure;
bar(categorical(models), acc*100);
title('Model Accuracy Comparison');
ylabel('Accuracy (%)');
grid on;

%% 9. Select best model and save
[~,bestIdx] = max(acc);
bestModel = models{bestIdx};
disp(['Best model selected: ', bestModel]);

if strcmp(bestModel,'TreeBagger')
    model = treeModel;
elseif strcmp(bestModel,'KNN')
    model = knnModel;
else
    model = svmModel;
end

save('fitnessModel.mat','model','featNames','Fs','windowSec','overlapSec');
disp('Model saved to fitnessModel.mat');

%% 10. Real-time simulation setup
refreshRate = 0.1; duration = 60;
metValues = struct('walking',3.5,'running',7.5,'sitting',1.3,'cycling',6.8);
userWeight = 70; totalCalories = 0; totalSteps = 0; heartRate = 75; baselineHR = 70;
activitySequence = {'walking','running','sitting','cycling'};
activityIndex = 1; windowSize = windowSec * Fs;
buffer = zeros(windowSize,3); prevPred = "";

% Create dashboard
fig = figure('Name','Fitness Tracker Dashboard','Color','w','Position',[150 100 1100 700]);
set(fig, 'CloseRequestFcn', @(src,evt)setappdata(src,'Closed',true));
setappdata(fig,'Closed',false);

ax1 = subplot(3,1,1);
hPlot = plot(ax1, nan, nan, 'r', nan, nan, 'g', nan, nan, 'b');
legend('X','Y','Z');
title(ax1,'Live Accelerometer'); ylim([-2 2]); grid on;

ax2 = subplot(3,1,2);
hBar = bar(ax2, zeros(1,numel(activities)));
xticklabels(ax2, activities); ylim(ax2,[0 1]); title('Activity Prediction');

ax3 = subplot(3,1,3); axis(ax3,[0 10 0 10]); axis off;
metricsText = text(0,8,'Initializing...','FontSize',12,'FontWeight','bold','VerticalAlignment','top');

disp('Starting stable live simulation...');
tic;

%% 11. Run real-time loop
while toc < duration
    if getappdata(fig,'Closed')
        disp('Figure closed by user. Ending simulation.');
        break;
    end

    actChange = mod(floor(toc/15), numel(activitySequence)) + 1;
    if actChange ~= activityIndex
        activityIndex = actChange;
        disp(['Switched to: ', activitySequence{activityIndex}]);
    end
    currentAct = activitySequence{activityIndex};

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
    feats = [mean(buffer), std(buffer), max(buffer), min(buffer)];
    Ttest = array2table(feats,'VariableNames',featNames(1:12));

    [predLabel, scores] = predict(treeModel, Ttest);
    predictedActivity = string(predLabel);

    set(hPlot(1), 'XData', 1:windowSize, 'YData', buffer(:,1));
    set(hPlot(2), 'XData', 1:windowSize, 'YData', buffer(:,2));
    set(hPlot(3), 'XData', 1:windowSize, 'YData', buffer(:,3));
    title(ax1, sprintf('Live Accelerometer — %s', predictedActivity));
    hBar.YData = scores;

    met = metValues.(char(predictedActivity));
    totalCalories = totalCalories + (met * 3.5 * userWeight / 200) / 60 * refreshRate;
    totalSteps = totalSteps + stepRate * refreshRate;
    heartRate = heartRate + 0.2 * ((baselineHR + 20 * (met / 3.5)) - heartRate);

    metricsText.String = sprintf(['Current: %s\nHeart Rate: %.1f bpm\n' ...
        'Calories: %.2f kcal\nSteps: %.0f\nTime: %.1f s'], ...
        predictedActivity, heartRate, totalCalories, totalSteps, toc);

    if predictedActivity ~= prevPred
        disp(['Detected: ', predictedActivity]);
        prevPred = predictedActivity;
    end

    drawnow limitrate;
    pause(refreshRate);
end

disp('Simulation complete or manually stopped.');
