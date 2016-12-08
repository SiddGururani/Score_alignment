function midi_mat_aligned = align_score( midi_path, wav_path, wSize, hop )
%ALIGN Summary of this function goes here
%   Detailed explanation goes here

[wav, fs_w] = audioread(wav_path);

% downmix audio
wav = mean(wav,2);
% midi_wav = mean(midi_wav,2);
midi_mat = readmidi(midi_path);

%compensate for the pitch offset
%process in cents rather than hertz
% [f0_midi,~] = estimatePitch(midi_wav, fs_m, hop, wSize, 'acf');
[f0_wav,~] = estimatePitch(wav, fs_w, hop, wSize, 'acf');
wav_pitch_contour_in_midi = 69+12*log2(f0_wav/440);
wav_pitch_contour_in_midi(wav_pitch_contour_in_midi == -Inf) = 0;

%remove leading and trailing zeros
a = find(wav_pitch_contour_in_midi ~= 0);
wav_pitch_contour_in_midi = wav_pitch_contour_in_midi(a(1):a(end));

%check if midi has pause and remove silence if no pauses
% shortest_note = min(midi_mat(:,7));
% for i = 1:numel(midi_mat(:,6)) - 1
%     current = midi_mat(i,6)+midi_mat(i,7);
%     diff_from_next(i) = abs(current - midi_mat(i+1,6));
% end
% 
% diff_from_next(diff_from_next<shortest_note) = [];
% if(numel(diff_from_next) == 0)
%     wav_pitch_contour_in_midi(a)= [];
% end

%Median filter wav_pitch_contour to remove simple octave errors
wav_pitch_contour_in_midi = medfilt1(wav_pitch_contour_in_midi,5);

% perform alignment
[~, ix, iy] = dtw(midi_mat(:,4), wav_pitch_contour_in_midi);

dx = diff(ix);
pos = find(dx);
true_pos = iy(pos);
time_pos = true_pos*hop/fs_w;
midi_mat_aligned = midi_mat;
midi_mat_aligned(2:end,6) = time_pos;
writemidi(midi_mat_aligned,'exp4.mid');

end