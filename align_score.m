function midi_mat = align_score( midi_path, wav_path, fs_w, wSize, hop )
%ALIGN Summary of this function goes here
%   Detailed explanation goes here

[wav, fs_m] = audioread(wav_path);

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
[f0_midi] = getUnwrappedMidiPitch(midi_mat,fs_w,hop);

[~, ix, iy] = dtw(midi_mat(:,4), wav_pitch_contour_in_midi);

dx = diff(ix);
pos = find(dx);
true_pos = iy(pos);
time_pos = true_pos*hop/fs_m;
midi_wav = midi_mat;
midi_wav(2:end,6) = time_pos;
writemidi(midi_wav,'exp4.mid');

end