clear all;clc

%% add path to the generate signals script
% https://data.mrc.ox.ac.uk/data-set/simulated-eeg-data-generator
% 1 subject; no components; without noise; add dB baseline method
% generate long ts put in 0, 500ms baseline ; 1 component make broad
% run full analysis with that with baseline correction 0 to -500ms
% copy and reflect, copy and reflect, copy and reflect, see if it produces
% same things tom hasgot (drops into negative power)
% -500ms baseline (non linearities)
% full baseline vs. copy and reflect baseline two different things
% code to calculate a distance between TF plots euclidiean distance
% characteristics of change  (not just a baseline shift)
% distribution of distances between plots (in power)
% main bit of the plot (difference at each point)
% cutting out time-frequency plot (not time-domain) - prebaselining to
% create something like a 500ms baseline 
% plot distribution - amount that I chop out   - how much I need to cut out
% when its plateued 
clear; clc;
addpath generate_signals\
addpath C:\External_Software\fieldtrip-20210807\
addpath E:\EEG-Neuroscience-PhD\code\synthetic_data\generate_signals

%https://www.youtube.com/watch?v=vqYL8gNO4BY

rng(42);

desired_time = 2.5; % in seconds
desired_fs = 500;
desired_noise_level = 0.6;
desired_trials = 300;
desired_participants = 1;
desired_total_trials = desired_participants * desired_trials;
desired_jitter = 25;
desired_peak_fs = 15;
desired_toi = [0, desired_time];
run_with_components = 1;

n_samples = desired_time * desired_fs;
peak_time = floor(n_samples/3)*2;

my_noise = noise(n_samples, desired_total_trials, desired_fs);
my_peak = peak(n_samples, desired_total_trials, desired_fs, desired_peak_fs, peak_time, desired_jitter);

if desired_total_trials > 1
    my_noise = split_vector(my_noise, n_samples);
    my_peak = split_vector(my_peak, n_samples);
else
    my_noise = my_noise';
    my_peak = my_peak';
end

%% add the pink noise on top of the sythetic data
signals = zeros(n_samples, desired_total_trials);
for t = 1:desired_total_trials
    noise_j = my_noise(:,t);
    peak_j = my_peak(:,t);

    if run_with_components == 1
        sig_w_pink_noise = peak_j + (noise_j*desired_noise_level);
    else
        sig_w_pink_noise = (noise_j*desired_noise_level);
    end
    signals(:,t) = sig_w_pink_noise;
end

%% create synth participants and generate their ERPs
make_plot = 1;
participants = {};
k_trials = desired_trials;
for p = 1:desired_participants
    
    if p == 1
        subset = signals(:,1:k_trials);
    else
        subset = signals(:,k_trials+1:k_trials + (desired_trials));
        k_trials = k_trials + desired_trials;
    end
    
    %subset = bpfilt(subset, 0.1, 30, desired_fs, 0);
    erp = mean(subset,2);
    erp  = bpfilt(erp, 0.1, 30, desired_fs, 0);
    %plot(erp)
    data.erp = erp;
    data.trials = subset;
    participants{p} = data;
    
    
end

%% for each trial in the data, find the baseline period and reflect it to a desired level

%  the amount of samples i.e. time (ms) / sampling rate
dividing_factor_to_find_events = 1000 / desired_fs; 
% the amount of chunks in time (ms)
reflection_duration = 200; 
% the chunk size i.e. how much to slice the data array by in samples
reflection_sample_size = reflection_duration / dividing_factor_to_find_events;

% when the baseline ends in (ms) from the data
baseline_end_in_ms = 1000; 
% where the baseline ends in samples
baseline_end_in_samples = baseline_end_in_ms/dividing_factor_to_find_events;
% where the baseline starts in (ms) from the data
baseline_start_in_ms = 800;
% where the baseline starts in samples
baseline_start_in_samples = baseline_start_in_ms/dividing_factor_to_find_events;

% how long we want to reflect for in (ms)
reflection_length_in_ms = 1000; 
% how long we want to reflect for in samples
desired_reflection_length_in_samples = reflection_length_in_ms/dividing_factor_to_find_events;
% number of times to reflect 
number_of_times_to_reflect = desired_reflection_length_in_samples/reflection_sample_size;

% reflect the ERP first
for p = 1:desired_participants
    
    participant_data = participants{p};
    erp = participant_data.erp;
    trials = participant_data.trials;

    % reflect for participant level ERPs
    % ---
    for i = 1:number_of_times_to_reflect
        
        if i == 1
            % get the baseline from the erps
            baseline = erp(baseline_start_in_samples:baseline_end_in_samples, 1);
        end
        
        %reflect = gnegate(baseline);
        reflect_flipped = flip(baseline);
    
        if i == 1
            new_baseline_erps = vertcat(reflect_flipped, baseline);
        else
            new_baseline_erps = vertcat(reflect_flipped, new_baseline_erps);
        end
        baseline = reflect_flipped;
    end
    % ---

    % reflect for trial level 
    % ---
    number_of_trials = size(trials, 2);
    new_trial_data = [];
    for k=1:number_of_trials
        for i=1:number_of_times_to_reflect
            trial = trials(:, k);
            
            if i == 1
                % get the baseline from the erps
                baseline = trial(baseline_start_in_samples:baseline_end_in_samples, 1);
            end

            %reflect = gnegate(baseline);
            reflect_flipped = flip(baseline);

            if i == 1
                new_baseline = vertcat(reflect_flipped, baseline);
            else
                new_baseline = vertcat(reflect_flipped, new_baseline);
            end
            baseline = reflect_flipped;
        end

        % since we have reflected 1000ms for the new data. Lets delete 
        % the old 1,000 ms data so we can make a fair comparison of
        % baselines
        trial = trial(size(new_baseline,1)+1:end);
        new_trial = vertcat(new_baseline, trial);
        new_trial_data(:, k) = new_trial;
    end
    % ---
    

    erp = vertcat(new_baseline_erps, erp);
    participants{p}.erp = erp;
    participants{p}.extended_baseline_trials = new_trial_data;
end



%% create using morlett waveletts on both the trial level
cfg1              = [];
cfg1.output       = 'pow';
cfg1.method       = 'wavelet';
%cfg1.taper = 'hanning';
cfg1.foi =   5:1:30; % in 1 Hz steps
cfg1.t_ftimwin = 3./cfg1.foi;
cfg1.toi          = desired_toi(1):0.05:desired_toi(2); % 2ms steps

end_value = desired_toi(2);  
start_value = desired_toi(1);
n_elements = n_samples;
step_size = (end_value-start_value)/(n_elements-1);
time1 = start_value:step_size:end_value;

% --- for the extended baseline
all_participant_data = [];
for p=1:desired_participants
    disp(p);
    data = participants{p};
    trials = data.trials;
    
    % without extended baseline -----
    % trial-level time-frequency representation
    trial_level.dimord = 'chan_time';
    trial_level.trial = create_ft_data(desired_trials, trials);
    trial_level.elec = {};
    trial_level.label = {'A1'};
    trial_level.time = create_fieldtrip_format(desired_trials,time1);
    tl_tf = ft_freqanalysis(cfg1, trial_level);
    

    % average of time-frequency representation
    newcfg = [];
    tl_tf = ft_freqdescriptives(newcfg, tl_tf);
    
    % baseline data
     newcfg = [];
     newcfg.baselinetype = 'db';
     newcfg.baseline = [0, 1.2];
     tl_tf = ft_freqbaseline(newcfg,tl_tf);
    


    % with extended baseline -----
    extended_trials = data.extended_baseline_trials;

    % with extended baseline -----
    % trial-level time-frequency representation
    trial_level.dimord = 'chan_time';
    trial_level.trial = create_ft_data(desired_trials, extended_trials);
    trial_level.elec = {};
    trial_level.label = {'A1'};
    trial_level.time = create_fieldtrip_format(desired_trials,time1);
    tl_tf_extended = ft_freqanalysis(cfg1, trial_level);

   % average of time-frequency representation
    newcfg = [];
    tl_tf_extended = ft_freqdescriptives(newcfg, tl_tf_extended);

     % baseline data
     newcfg = [];
     newcfg.baselinetype = 'db';
     newcfg.baseline = [0, 1.2];
     tl_tf_extended = ft_freqbaseline(newcfg,tl_tf_extended);
    % without extended baseline -----
end

cfg = [];
cfg.baseline = 'no';
cfg.xlim = [desired_toi(1),desired_toi(2)];
cfg.channel = 'A1';
cfg.zlim = [-2, 3];
ft_singleplotTFR(cfg, tl_tf);
title('Without Extended Baseline', 'FontSize', 15)
xline(1.2, '--r', 'LineWidth', 2)
xlabel('Time')
ylabel('Power')
set(gcf,'Position',[100 100 1000 500])
exportgraphics(gcf,"E:\EEG-Neuroscience-PhD\code\synthetic_data\outputs\without_extended.png",'Resolution',500);
close;

% with extended baseline
cfg = [];
cfg.baseline = 'no';
cfg.xlim = [desired_toi(1),desired_toi(2)];
cfg.channel = 'A1';
cfg.zlim = [-2, 3];
ft_singleplotTFR(cfg, tl_tf_extended);
title('With Extended Baseline', 'FontSize', 15)
xline(1.2, '--r', 'LineWidth', 2)
xlabel('Time')
ylabel('Power')
set(gcf,'Position',[100 100 1000 500])
exportgraphics(gcf,"E:\EEG-Neuroscience-PhD\code\synthetic_data\outputs\with_extended.png",'Resolution',500);
close;


% compare the tf representations

without_extended = tl_tf.powspctrm;
without_extended_time = tl_tf.time;

with_extended = tl_tf_extended.powspctrm;
with_extended_time = tl_tf_extended.time;

tl_tf_extended.powspctrm = abs(with_extended-without_extended);
cfg = [];
cfg.baseline = 'no';
cfg.xlim = [desired_toi(1),desired_toi(2)];
cfg.channel = 'A1';
cfg.zlim = [-2, 3];
ft_singleplotTFR(cfg, tl_tf_extended);
title('Absoulute Difference in Power', 'FontSize', 15)
xline(1.2, '--r', 'LineWidth', 2)
xlabel('Time')
ylabel('Power')
set(gcf,'Position',[100 100 1000 500])
exportgraphics(gcf,"E:\EEG-Neuroscience-PhD\code\synthetic_data\outputs\difference_plot.png",'Resolution',500);
close;

difference = abs(without_extended-with_extended);

%% gets the frequency of maximum power
function freq = freq_of_max_pow(data)
    f = data.freq;
    d = squeeze(data.powspctrm);
    [row, col] = find(ismember(d, max(d(:))));
    freq = f(row);
end


%% converts to a FT format
function data = create_fieldtrip_format(n, series)
    data = {};
    for k = 1:n
        data{k} = series;
    end
end

function dataset = create_ft_data(n, data)
    dataset = {};
    data = data';
    for k =1:n
        dataset{k} = data(k,:);
    end
end

%% split vector
function v = split_vector(vector, n_samples)
    n_chunks = size(vector,2)/n_samples;

    curr_chunk = n_samples;
    v = zeros(n_samples, n_chunks);
    for chunk = 1:n_chunks
        if chunk == 1
            c = vector(1, 1:curr_chunk);
            curr_chunk = curr_chunk + n_samples;
        else
            c = vector(1, (curr_chunk-n_samples)+1: curr_chunk);
            curr_chunk = curr_chunk + n_samples;
        end

        c = c';
        v(:, chunk) = c(:,1);
        
    end
end

%% increase width of wavelett with higher Fs
function width = increasing_width_with_time(K, woi)
    width = ones(K,1);
    for j = 1:size(woi,2)
        if j == 1
            start_i = j;
            end_i = K/size(woi,2);
            width(start_i:end_i) = ones(1,K/size(woi,2)) * woi(j); 
        else
            start_i = K/size(woi,2);
            end_i = end_i + K/size(woi,2);
            width(start_i+1:end_i) = ones(1,K/size(woi,2)) * woi(j); 
        end
    end
end