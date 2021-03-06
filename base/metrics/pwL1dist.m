function D = pwL1dist(X1, X2, w)
% Compute the pairwise L1-norm distances
%
%   D = pwL1dist(X1, X2);
%       computes the L1-norm distance between pairs of column vectors in 
%       X1 and X2. 
%
%       Suppose the vector dimension is d, then X1 and X2 should be
%       matrices of size d x m and d x n. In this case, the output
%       is a matrix of size m x n, where D(i, j) is the distance between
%       X1(:,i) and X2(:,j).
%
%   D = pwL1dist(X1, X2, w);
%       computes the weighted L1-norm distance between column vectors
%       in X1 and X2. The weighted L1-norm distance is defined by
%
%           d = sum_i w(i) * |x1(i) - x2(i)|
%
%       In the input, w should be a column vector.
%

%   Created by Dahua Lin, on Aug 2, 2010
%

%% verify input

if nargin < 2 || isempty(X2)
    X2 = X1;
end

if ~(isfloat(X1) && ndims(X1) == 2 && isfloat(X2) && ndims(X2) == 2)
    error('pwL1dist:invalidarg', 'X1 and X2 should be both real matrices.');
end

if size(X1,1) ~= size(X2,1)
    error('pwL1dist:invalidarg', 'X1 and X2 should have the same number of rows.');
end

if nargin >= 3    
    if ~(ndims(w) == 2 && size(w, 2) == 1 && isreal(w))
        error('pwL1dist:invalidarg', 'w should be a real row vector.');
    end
    
    X1 = bsxfun(@times, X1, w);
    X2 = bsxfun(@times, X2, w);
end

%% main

n1 = size(X1, 2);
n2 = size(X2, 2);

D = zeros(n1, n2);

if n1 < n2
    for i = 1 : n1
        D(i, :) = sum(abs(bsxfun(@minus, X2, X1(:,i))), 1) ;
    end
else
    for i = 1 : n2
        D(:, i) = sum(abs(bsxfun(@minus, X1, X2(:,i))), 1).';
    end
end

