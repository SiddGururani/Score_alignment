function midi_mat_new = updateMidiOnsets(midi_mat, onsetTime, tolerance)

% function midi_mat_new = updateMidiOnsets(midi_mat, onsetTime, fs, hopSize, tolerance)
% Input Arguments: 
% midi_mat: N x 7 matrix, after updating the time stamps using DTW
% onsetTime: M x 1 array, containing Onset time in seconds
% fs: Sampling frequency in Hertz
% hopSize: hop used in onset detection, should be same as one used for
%          align_score as well
% tolerance: Time in milliseconds of how far the actual onsets can be from
%            the midi note onsets. 100 milliseconds by default.


if (nargin == 3)
    tolerance = 100;        % tolerance is 100ms by default
end

N = length(midi_mat);
M = length(onsetTime);
tol_ms = tolerance*power(10,-3);    % tolerace in milliseconds
midi_mat_new = midi_mat;


% If more than 1 note have same onset (Caused by dtw alignment),
% Spread them equally before correcting the onsets to nearest actual onsets

k = 2;
while(k<=N-1)
    prevOnset = midi_mat(k-1,6);
    midiOnset = midi_mat(k,6);
    nextOnset = midi_mat(k+1,6);
    if (abs(prevOnset-midiOnset)) < 0.02 && ...
            (abs(midiOnset-nextOnset)) > tol_ms
        midiOnset =  (prevOnset+nextOnset)/2;
        midi_mat_new(k,6) = midiOnset;
    end
    k = k+1;
end


% Correct onsets by updating onsets with nearest actual onsets given
% by the onset detection algorithm.
k = 1;
for i=1:N-1
    midiOnset = midi_mat(i,6);
    while(k<M)
        if ((abs(onsetTime(k)-midiOnset)) < tol_ms && ... % actual onset within tolerance
                onsetTime(k)<midi_mat(i+1,6))             % and within next onset
            midi_mat_new(i,6) = onsetTime(k);            
        else
            if (onsetTime(k) > midiOnset)                 % Verify only till current midiOnset
                break;
            end
        end        
        k = k+1;
    end   
end
 
end