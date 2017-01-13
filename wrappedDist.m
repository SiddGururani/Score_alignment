function D = wrappedDist(vect1, vect2, N)

% check if inputs are vectors or not
vect1 = checkVect(vect1);
vect2 = checkVect(vect2);

D = zeros(numel(vect1), numel(vect2));
for i = 1:numel(vect1)
    for j = 1:numel(vect2)
        diff = abs(vect1(i) - vect2(j));
        D(i,j) = mod(diff, N);
    end
end

end

function vect = checkVect(vect)
    [r,c] = size(vect);
    if c ~= 1
        if r == 1
            vect = vect';
        else
            disp('Only works for vectors!')
        end
    end
end