function [midi_mat_aligned, notes_altered, dtw_cost, path] = alignScore( midi_path, f0_wav, wav, fs_w, wSize, hop )
%ALIGNSCORE: Uses dynamic time warping to align the original score of
%the current exercise with the picth contour of the student performance
%   INPUT:
%       midi_path:  path to the ground truth MIDI score
%       f0_wav:     pitch contour of the student performance
%       wav_path:   path to student performance, for onset detection
%       wSize:      window size used in pitch estimation
%       hop:        hop size used in pitch estimation

% [wav, fs_w] = audioread(wav_path);

% downmix audio
% wav = mean(wav,2);
% midi_wav = mean(midi_wav,2);
midi_mat = readmidi(midi_path);

%normalize midi time to multiples of shortest note
%Rounding after multiplying by 2 to take into account dotted notes as well
shortest_note = min(midi_mat(:,2));
midi_mat(:,2) = midi_mat(:,2)./shortest_note;
midi_mat(:,2) = round(midi_mat(:,2)*2)/2;

%compensate for the pitch offset
%process in cents rather than hertz
% [f0_midi,~] = estimatePitch(midi_wav, fs_m, hop, wSize, 'acf');
% [f0_wav,~] = estimatePitch(wav, fs_w, hop, wSize, 'acf');
wav_pitch_contour_in_midi = 69+12*log2(f0_wav/440);
wav_pitch_contour_in_midi(wav_pitch_contour_in_midi == -Inf) = 0;

%remove zeros
lead_trail_z = find(wav_pitch_contour_in_midi ~= 0);
wav_pitch_contour_in_midi = wav_pitch_contour_in_midi(lead_trail_z(1):lead_trail_z(end));

a = find(wav_pitch_contour_in_midi == 0);
wav_pitch_contour_in_midi(a) = [];

%Median filter wav_pitch_contour to remove simple octave errors
% wav_pitch_contour_in_midi = medfilt1(wav_pitch_contour_in_midi,5);

% perform alignment
% [~, ix, iy] = dtw(midi_mat(:,4), wav_pitch_contour_in_midi);
D = wrappedDist(midi_mat(:,4), wav_pitch_contour_in_midi, 12);
[path, dtw_cost] = ToolSimpleDtw(D);
ix = path(:,1)';
iy = path(:,2)';

dx = diff(ix);
pos = find(dx);
true_pos = iy(pos);
time_pos = true_pos*hop/fs_w;
midi_mat_aligned = midi_mat;
midi_mat_aligned(2:end,6) = time_pos;

nvt = mySpectralFlux(wav, wSize, hop);
%remove zero frames from novelty function as well
nvt = nvt(lead_trail_z(1):lead_trail_z(end));
nvt(a) = [];
onsets = myOnsetDetection(nvt, fs_w, wSize, hop);
midi_mat_aligned = updateMidiOnsets(midi_mat_aligned, midi_mat, onsets, 50);

%Modify durations: Note onset difference for all notes but the last
%for last note, use length of pitch contour to match the end points.
midi_mat_aligned(1:end-1,7) = diff(midi_mat_aligned(:,6));
midi_mat_aligned(end, 7) = numel(wav_pitch_contour_in_midi)*hop/fs_w - midi_mat_aligned(end, 6);

%Add silences back at the appropriate location
notes_altered = [];
% tolerance = 4*hop/fs_w;
for i = 1:numel(a)
    pos = a(i);
    prior_notes = find(midi_mat_aligned(:,6)<pos*hop/fs_w);
    previous_note = prior_notes(end);
    %check if note occurs after silence occurs
%     duration_after_silence = midi_mat_aligned(previous_note,6) + midi_mat_aligned(previous_note, 7) - pos*hop/fs_w;
%     if(duration_after_silence < tolerance)
%         midi_mat_aligned(previous_note, 7) = midi_mat_aligned(previous_note, 7) - duration_after_silence;
%         midi_mat_aligned = addSilence(midi_mat_aligned, previous_note, hop, fs_w);
%     else
%         %split the note
        [midi_mat_aligned, split_note] = splitNote(midi_mat_aligned, previous_note, pos, hop, fs_w);
        notes_altered = [notes_altered; split_note];
%     end
end

% z = wav_pitch_contour_in_midi==0;
% num_zeros = 0;
% sil_tolerance = 0.05;
% for i = 1:numel(z)
%     if z(i) == 1
%         num_zeros = num_zeros + 1;
%         continue;
%     else
%         if num_zeros == 0
%             continue;
%         else
%             if num_zeros*hop/fs_w >= sil_tolerance
%                 pos = find(midi_mat_aligned(:,6) <= (i - num_zeros)*hop/fs_w);
%                 pos = pos(end);
%                 midi_mat_aligned(pos,7) = midi_mat_aligned(pos,7) - num_zeros*hop/fs_w;
%             end
%             num_zeros = 0;
%         end
%     end
% end

%Add back starting silence to midi
midi_mat_aligned(:,6) = midi_mat_aligned(:,6) + lead_trail_z(1)*hop/fs_w;

writemidi(midi_mat_aligned,'exp3.mid');
end

function midi_mat = addSilence(midi_mat, previous_note, hop, fs_w)
    for i = previous_note + 1:size(midi_mat,1)
        midi_mat(i,6) = midi_mat(i,6) + hop/fs_w; %add one frame of silence
    end
end

function [midi_mat, split_note] = splitNote(midi_mat, previous_note, pos, hop, fs_w)
    split_note = [];
    onset_time = midi_mat(previous_note,6);
    duration = midi_mat(previous_note, 7);
    
    onset_note_1 = onset_time;
    duration_note_1 = (pos)*hop/fs_w - onset_time;

    onset_note_2 = (pos)*hop/fs_w;
    duration_note_2 = onset_time+duration - (pos)*hop/fs_w;

    % check if silence is after note off or during note to split
    if((pos-1)*hop/fs_w - onset_time >= duration)
        midi_mat = addSilence(midi_mat, previous_note, hop, fs_w);
    else
        if(duration_note_1 <= 1e-6) %note was not played
            midi_mat(previous_note,7) = 0;
        else %split note
            split_note = previous_note;
            note_1 = [onset_note_1, duration_note_1, midi_mat(previous_note, 3:5), onset_note_1, duration_note_1];
            note_2 = [onset_note_2, duration_note_2, midi_mat(previous_note, 3:5), onset_note_2, duration_note_2];    
            midi_mat = [midi_mat(1:previous_note-1,:); note_1; note_2; midi_mat(previous_note+1:end,:)];
            midi_mat = addSilence(midi_mat, previous_note, hop, fs_w);
        end
    end
end