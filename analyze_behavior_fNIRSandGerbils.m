%% analyze_behavior_fNIRSandGerbils
%% Author: Benjamin Richardson

subject_ID = char('bentest','emayatest','victoriatest','stest','longtest1','longtest2');

curr_subject_ID = char('longtest1','longtest2');
%% Load in Relevant files

all_click_info = readtable('C:\Users\benri\Documents\GitHub\fNIRSandGerbils\data\fNIRSandGerbils.xlsx','Format','auto');

by_subject_behavior_info = struct();
all_subjects_click_times = [];


for isubject = 1:size(curr_subject_ID,1)
    % load words for this subject
    stim_info_filename = ['C:\Users\benri\Documents\GitHub\fNIRSandGerbils\stim\s_',strtrim(curr_subject_ID(isubject,:)),'\',strtrim(curr_subject_ID(isubject,:)),'_alltrialwords.mat'];
    load(stim_info_filename) % loads all_word_order and tOnset
    
    by_subject_behavior_info(isubject).subject_ID = strtrim(curr_subject_ID(isubject,:));
    num_hits = 0;
    num_FAs = 0;
    num_color_words = 0;
    num_nontarget_words = 0;
    subject_ID = strtrim(string(curr_subject_ID(isubject,:)));
    numtotalwords = 30;
    wordlength = 0.30; %length of sound file
    fs = 44100;
    overlap = 0.1;
    tVec = 0:1/fs:(wordlength*numtotalwords) - (overlap*(numtotalwords-1)); %1/fs = seconds per sample

    %% Behavior processing

    which_rows_this_subject = find(all_click_info.S == string(subject_ID));

    %% Get information from files

    trials = all_click_info.Trial(which_rows_this_subject);
    blocks = all_click_info.Block(which_rows_this_subject);
    conditions = all_click_info.Condition(which_rows_this_subject);
    click_times = all_click_info(which_rows_this_subject,9:end); % will include NaNs! accounted for later
    soundfiles_by_trial = all_click_info.Soundfile(which_rows_this_subject);

    %% Calculate hits, FA
    % Loop through each trial, and calculate hits, false alarms, correct
    % rejections, and misses

    n_trials = length(trials);

    hits_and_FAs = struct();
    all_color_times = struct();
    threshold_window_start = 0.2; % seconds
    threshold_window_end = 0.8; % seconds
    double_click_threshold = 0.05;

    by_subject_behavior_info(isubject).nearest_click_distances = struct();
    color_words = string({'red','green','blue','white'});
    for itrial = 1:n_trials

        current_click_times = table2array(click_times(itrial,:));
        %% throw out click times past trial onset
        %current_click_times(current_click_times > 15) = nan;
        current_click_times = current_click_times(~isnan(current_click_times));

        all_subjects_click_times = [all_subjects_click_times,current_click_times];

        %% find the appropriate color times for this trial (NOT IN ORDER)
        all_words_this_trial = all_word_order(itrial,:);
        color_indices_this_trial = find(ismember(all_words_this_trial,color_words) == 1);
        masker_indices_this_trial = find(~ismember(all_words_this_trial,color_words) == 1);

        current_target_color_times = tOnset(color_indices_this_trial);
        current_masker_times = tOnset(masker_indices_this_trial);

        current_target_color_words = all_words_this_trial(color_indices_this_trial);


        hit_windows = zeros(1,length(tVec));
        FA_windows = zeros(1,length(tVec));
        
        % specify hit windows
        for i = 1:length(current_target_color_times)
            [~,start_index_hit_window] = min(abs(tVec - (current_target_color_times(i)+threshold_window_start)));
            [~,end_index_hit_window] = min(abs(tVec - (current_target_color_times(i)+threshold_window_end)));

            hit_windows(start_index_hit_window:end_index_hit_window) = 1;
        end

        % specify false alarm windows
        for i = 1:length(current_masker_times)
            [~,start_index_FA_window] = min(abs(tVec - (current_masker_times(i)+threshold_window_start)));
            [~,end_index_FA_window] = min(abs(tVec - (current_masker_times(i)+threshold_window_end)));

            FA_windows(start_index_FA_window:end_index_FA_window) = 1;
        end

        FA_windows(hit_windows == 1) = 0; % any time there is a hit window, there should not be an FA window 


        %% Calculate difference between each click and each target color time
        all_target_click_distances= [];
        for icolortime = 1:length(current_target_color_times)
            all_target_click_distances(icolortime,:) = current_click_times - current_target_color_times(icolortime);
        end
        all_target_click_distances(all_target_click_distances < 0) = nan;

        %% Find the nearest color time to each click (minimum positive value of click_distances in each column)
        by_subject_behavior_info(isubject).nearest_target_click_distances(itrial).value = [];
        by_subject_behavior_info(isubject).nearest_target_color_word(itrial).value = [];
        [~,nearest_click] = min(abs(all_target_click_distances),[],1);
        for i = 1:length(current_click_times)
            if isnan(all_target_click_distances(:,i)) == ones(1,length(current_target_color_times)) % all of these clicks were before the first word
                nearest_click(i) = nan;
            else
                by_subject_behavior_info(isubject).nearest_target_color_word(itrial).value = [by_subject_behavior_info(isubject).nearest_target_color_word(itrial).value, current_target_color_words(nearest_click(i))];
                by_subject_behavior_info(isubject).nearest_target_click_distances(itrial).value = [by_subject_behavior_info(isubject).nearest_target_click_distances(itrial).value, all_target_click_distances(nearest_click(i),i)];
            end

        end

        by_subject_behavior_info(isubject).condition(itrial).value = conditions(itrial);

        % find first non nan value in each row (color word) in
        % all_click_distances
%         if ~isempty(all_target_click_distances)
%             response_by_target_color_word = [];
%             for irow = 1:size(all_target_click_distances,1)
%                 current_row = all_target_click_distances(irow,:);
%                 values = current_row(~isnan(current_row));
%                 if isempty(values)
%                     response_by_target_color_word = [response_by_target_color_word, 0];
%                 else
%                     response_by_target_color_word = [response_by_target_color_word, values(1)];
%                 end
%             end
% 
%             by_subject_behavior_info(isubject).num_hits(itrial).value = sum( (threshold_window_start < response_by_target_color_word).*(response_by_target_color_word < threshold_window_end));
%             by_subject_behavior_info(isubject).num_FAs(itrial).value = length(current_click_times) - sum( (threshold_window_start < response_by_target_color_word).*(response_by_target_color_word < threshold_window_end));
%             by_subject_behavior_info(isubject).difference_score(itrial).value = length(current_click_times) - length(current_target_color_times);
%         else
%             by_subject_behavior_info(isubject).num_hits(itrial).value = 0;
%             by_subject_behavior_info(isubject).num_FAs(itrial).value = 0;
%         end

        by_subject_behavior_info(isubject).num_hits(itrial).value = 0;
        by_subject_behavior_info(isubject).num_FAs(itrial).value = 0;
        for iclick = 1:length(current_click_times)
            [~,current_click_index] = min(abs(tVec - current_click_times(iclick)));

            if hit_windows(current_click_index) == 1
                by_subject_behavior_info(isubject).num_hits(itrial).value = by_subject_behavior_info(isubject).num_hits(itrial).value + 1;
            elseif FA_windows(current_click_index) == 1
                by_subject_behavior_info(isubject).num_FAs(itrial).value = by_subject_behavior_info(isubject).num_FAs(itrial).value + 1;
            end

        end

        if (by_subject_behavior_info(isubject).num_FAs(itrial).value + by_subject_behavior_info(isubject).num_hits(itrial).value) > length(current_click_times)
            disp("Uh Oh! More than the number of clicks!")
        end

        by_subject_behavior_info(isubject).difference_score(itrial).value = length(current_click_times) - length(current_target_color_times);

        by_subject_behavior_info(isubject).num_target_color_words(itrial).value = length(current_target_color_times);
        if by_subject_behavior_info(isubject).num_hits(itrial).value > by_subject_behavior_info(isubject).num_target_color_words(itrial).value
            disp('Uh Oh! Number of hits is greater than number of target words')
        end

        by_subject_behavior_info(isubject).num_masker_words(itrial).value = length(current_masker_times);

        if by_subject_behavior_info(isubject).num_FAs(itrial).value > by_subject_behavior_info(isubject).num_masker_words(itrial).value
            disp('Uh Oh! Number of FAs is greater than number of masker words')
        end

    end



end

%% Histogram of all click times
figure;histogram(all_subjects_click_times,'BinWidth',0.1)
xlabel('Time Since Stimulus Onset (seconds)','FontSize',18)
ylabel('Number of Clicks Total','FontSize',18)
title('Click Counts vs. Time since Stimulus Onset','FontSize',18);

%% histogram of click distance from nearest target word
all_nearest_click_distances = [];
for isubject = 1:size(curr_subject_ID,1)
    for itrial = 1:n_trials
        all_nearest_click_distances = [all_nearest_click_distances,by_subject_behavior_info(isubject).nearest_target_click_distances(itrial).value];
    end
end
figure;
p1 = histogram(all_nearest_click_distances,'BinWidth',0.05);
xticks(tOnset - 1);
p2 = xline(tOnset - 1);
p3 = xline([0.2,0.6],'r','LineWidth',3);
ylabel('Number of Clicks Total','FontSize',18)
xlabel('Time Since Nearest Target Word Onset (seconds)','FontSize',18)
title('Clicks w.r.t. Target Word Onset all subjects all trials','FontSize',18)
legend({'Click Counts','Word Onset Times','Antje Hit Window'})
%% histogram of reaction times split up by trial type

all_nearest_click_distances_condition1 = [];
all_nearest_click_distances_condition2 = [];
for isubject = 1:size(curr_subject_ID,1)
    for itrial = 1:n_trials
        this_condition = by_subject_behavior_info(isubject).condition(itrial).value;
        if this_condition == 1
            all_nearest_click_distances_condition1 =  [all_nearest_click_distances_condition1, by_subject_behavior_info(isubject).nearest_target_click_distances(itrial).value];
        elseif this_condition == 2
            all_nearest_click_distances_condition2 =  [all_nearest_click_distances_condition2, by_subject_behavior_info(isubject).nearest_target_click_distances(itrial).value];
        end

    end
end
figure;
x = [all_nearest_click_distances_condition1,all_nearest_click_distances_condition2];
g = [zeros(length(all_nearest_click_distances_condition1), 1); ones(length(all_nearest_click_distances_condition2), 1)];
violinplot(x,g);
xticks(1:2)
xticklabels({'scrambled','unscrambled'})
xlabel('Condition','FontSize',18)
ylabel('Click Time w.r.t. \newline Color Word Onset (seconds)','FontSize',18)
title('Click Times since Color Word Onset vs. Condition','FontSize',18);
%% histogram of reaction times split up by color word
red_nearest_click_times = [];
white_nearest_click_times = [];
green_nearest_click_times = [];
blue_nearest_click_times = [];

for isubject = 1:size(curr_subject_ID,1)
    for itrial = 1:n_trials
        for i = 1:length(by_subject_behavior_info(isubject).nearest_target_click_distances(itrial).value)
            if by_subject_behavior_info(isubject).nearest_target_color_word(itrial).value(i) == 'red'
                red_nearest_click_times = [red_nearest_click_times, by_subject_behavior_info(isubject).nearest_target_click_distances(itrial).value(i)];
            elseif by_subject_behavior_info(isubject).nearest_target_color_word(itrial).value(i) == 'white'
                white_nearest_click_times = [white_nearest_click_times, by_subject_behavior_info(isubject).nearest_target_click_distances(itrial).value(i)];

            elseif by_subject_behavior_info(isubject).nearest_target_color_word(itrial).value(i) == 'green'
                green_nearest_click_times = [green_nearest_click_times, by_subject_behavior_info(isubject).nearest_target_click_distances(itrial).value(i)];

            elseif by_subject_behavior_info(isubject).nearest_target_color_word(itrial).value(i) == 'blue'
                blue_nearest_click_times = [blue_nearest_click_times, by_subject_behavior_info(isubject).nearest_target_click_distances(itrial).value(i)];

            end

        end
    end
end
figure;
x = [red_nearest_click_times,white_nearest_click_times,green_nearest_click_times,blue_nearest_click_times];
g = [zeros(length(red_nearest_click_times), 1); ones(length(white_nearest_click_times), 1); 2*ones(length(green_nearest_click_times), 1);...
    3*ones(length(blue_nearest_click_times), 1);];
violinplot(x,g);
xticks(1:4)
xticklabels({'Red','White','Green','Blue'})
xlabel('Color','FontSize',18);
ylabel('Click Time w.r.t. \newline Color Word Onset (seconds)','FontSize',18)
title('Click Times since Color Word Onset vs. Color Word','FontSize',18);


%% Hit and False Alarm Rates
hit_rates_condition1 = nan(size(curr_subject_ID,1),24);
hit_rates_condition2 = nan(size(curr_subject_ID,1),24);

FA_rates_condition1 = nan(size(curr_subject_ID,1),24);
FA_rates_condition2 = nan(size(curr_subject_ID,1),24);

difference_scores_condition1 = nan(size(curr_subject_ID,1),24);
difference_scores_condition2 = nan(size(curr_subject_ID,1),24);


for isubject = 1:size(curr_subject_ID,1)
    ionset1 = 0;
    ionset2 = 0;
    for itrial = 1:n_trials
        this_condition = by_subject_behavior_info(isubject).condition(itrial).value;
        if this_condition == 1
            ionset1 = ionset1 + 1;
            hit_rates_condition1(isubject,ionset1) =   by_subject_behavior_info(isubject).num_hits(itrial).value/by_subject_behavior_info(isubject).num_target_color_words(itrial).value;
            FA_rates_condition1(isubject,ionset1) =  by_subject_behavior_info(isubject).num_FAs(itrial).value/by_subject_behavior_info(isubject).num_target_color_words(itrial).value;
            difference_scores_condition1(isubject,ionset1) = by_subject_behavior_info(isubject).difference_score(itrial).value;
        elseif this_condition == 2
            ionset2 = ionset2 + 1;

            hit_rates_condition2(isubject,ionset2) = by_subject_behavior_info(isubject).num_hits(itrial).value/by_subject_behavior_info(isubject).num_target_color_words(itrial).value;
            FA_rates_condition2(isubject,ionset2) =  by_subject_behavior_info(isubject).num_FAs(itrial).value/by_subject_behavior_info(isubject).num_target_color_words(itrial).value;
            difference_scores_condition2(isubject,ionset2) = by_subject_behavior_info(isubject).difference_score(itrial).value;

        end

    end
end
figure;
all_hitrates = cat(3,hit_rates_condition1,hit_rates_condition2);
all_FArates = cat(3,FA_rates_condition1,FA_rates_condition2);
all_difference_scores = cat(3,difference_scores_condition1,difference_scores_condition2);
chance_rate = (1/25)*ones(length(curr_subject_ID),6,7);
%all_hitrates = all_hitrates + 0.001;
d_primes = norminv(all_hitrates) - norminv(all_FArates);
% find subjects with d_primes of Inf or -Inf (to exclude)

d_primes(d_primes == Inf) = nan;
d_primes(d_primes == -Inf) = nan;
d_primes(d_primes < 0) = nan;


all_hitrates(all_hitrates == 0) = nan;
all_FArates(all_FArates == 0) = nan;
plot(1:2,squeeze(nanmean(all_hitrates,2)),'-o');
title('hit rates')
ylim([0 1])
xticks(1:2)
xticklabels({'scrambled','unscrambled'})

figure;
plot(1:2,squeeze(nanmean(all_FArates,2)),'-o');
title('FA rates')
ylim([0 1])
xticks(1:2)
xticklabels({'scrambled','unscrambled'})

figure;
plot(1:2,squeeze(nanmean(d_primes,2)),'-o');
title('D prime')
ylim([0,1])
xticks(1:2)
xticklabels({'scrambled','unscrambled'})

figure;boxplot(squeeze(nanmean(d_primes,2)))
ylabel('d prime')
xlabel('Condition')
ylim([0 1])
xticks(1:2)
xticklabels({'scrambled','unscrambled'})

figure;
boxplot(squeeze(nanmean(all_difference_scores,2)))
ylabel('difference score')
xlabel('Condition')
ylim([-2 2])
xticks(1:2)
xticklabels({'scrambled','unscrambled'})

figure;
histogram(difference_scores_condition1(:))
hold on
histogram(difference_scores_condition2(:))
legend({'Scrambled','Unscrambled'})
xlabel('Difference Score','FontSize',18)
ylabel('Frequency of occurrence','FontSize',18)