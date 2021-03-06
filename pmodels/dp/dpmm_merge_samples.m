function s = dpmm_merge_samples(M, obs, H, ss, varargin)
%DPMM_MERGE_SAMPLES Merges multiple samples from the same chain into one
%
%   s = dpmm_merge_samples(M, obs, H, ss, ...);
%
%       merges multiple DPMM samples drawn from a MCMC chain (those
%       produced by the method make_output of dpmm class) into a single
%       sample by voting.
%
%       Input arguments:
%       - M:        the DPMM model
%
%       - H:        the struct of inheritance (empty if no inheritance)
%
%       - ss:       the sequence of samples
%
%       One can customize the following options via name/value pairs.
%       
%       - rthres:           the threshold of ratio. If the count of an 
%                           atom takes a ratio less than rthres, the atom 
%                           will be discarded, and the corresponding 
%                           observations will be assigned the labels of 
%                           the most fitted atom in the remaining set. 
%                           (default = 0);
%
%       - redraw_iters:     the number of iterations to redraw an atom.
%                           (default = 1).
%
%

% Created by Dahua Lin, on Sep 26, 2011.
%

%% verify input arguments

if ~isa(M, 'dpmm')
    error('dpmm_merge_samples:invalidarg', ...
        'M should be an instance of the class dpmm.');
end

amdl = M.amodel;
basedist = M.basedist;

n = amdl.get_num_observations(obs);

if ~isstruct(ss) && isvector(ss)
    error('dpmm_merge_samples:invalidarg', 'ss should be a struct vector.');
end

if ~isempty(H)
    if ~(isstruct(H) && isfield(H, 'tag') && strcmp(H.tag, 'dpmm_inherits'))
        error('dpmm_merge_samples:invalidarg', ...
            'H should be either empty or a dpmm_inherits struct.');
    end
    Kp = H.num;
else
    Kp = 0;
end

rthres = 0;
redraw_iters = 1;

if ~isempty(varargin)
    
    onames = varargin(1:2:end);
    ovals = varargin(2:2:end);
    
    if ~(numel(onames) == numel(ovals) && iscellstr(onames))
        error('dpmm_merge_samples:invalidarg', 'Invalid option list.');
    end
    
    for i = 1 : numel(onames)
        
        cn = onames{i};
        cv = ovals{i};
        
        switch cn
            case 'rthres'
                if ~(isfloat(cv) && isreal(cv) && isscalar(cv) && cv >= 0 && cv < 1)
                    error('dpmm_merge_samples:invalidarg', ...
                        'rthres should be a real value in [0, 1).');
                end
                rthres = cv;
                
            case 'redraw_iters'
                if ~(isnumeric(cv) && isscalar(cv) && cv == fix(cv) && cv >= 1)
                    error('dpmm_merge_samples:invalidarg', ...
                        'redraw_iters should be a positive integer scalar.');
                end
                redraw_iters = cv;
        end
    end    
end


%% main

% get maximum atom id

max_aid = max([ss.max_atom_id]);

% voting

all_labels = vertcat(ss.labels);
labels = mode(all_labels, 1);
[atom_ids, counts, grps, z] = uniqvalues(labels, 'CGI');
K = numel(atom_ids);

% discard 

unlabeled = [];

if rthres > 0
    cthres = rthres * n;
    if any(counts < cthres)
        di = find(counts < cthres);
        if numel(di) == K
            error('dpmm_merge_samples:rterror', ...
                'No atom can be retained after thresholding.');
        end
        
        unlabeled = [grps{di}]; 
        
        atom_ids(di) = [];
        counts(di) = []; %#ok<NASGU>
        grps(di) = [];
        
        zmap = zeros(1, K);
        ri = setdiff(1:K, di);
        zmap(ri) = 1 : numel(ri);
        K = numel(ri);        
        z = zmap(z);
    end
end

% re-draw atoms 

atoms = cell(1, K);
auxes = cell(1, K);

if Kp == 0
    for k = 1 : K
        [atoms{k}, auxes{k}] = redraw_atom(amdl, basedist, obs, grps{k}, redraw_iters);
    end
else
    [is_inherit, pids] = ismember(atom_ids, H.atom_ids);
    for k = 1 : K
        if is_inherit(k)
            pri_k = H.atoms{pids(k)};
        else
            pri_k = basedist;
        end
        [atoms{k}, auxes{k}] = redraw_atom(amdl, pri_k, obs, grps{k}, redraw_iters);
    end
end

% relabel observations whose atoms were discarded

if ~isempty(unlabeled)
    
    assert(all(z(unlabeled) == 0));
    
    L = zeros(K, numel(unlabeled));    
    for k = 1 : K        
        llik = amdl.evaluate_logliks(atoms{k}, obs, auxes{k}, unlabeled);
        L(k, :) = llik;
    end    
    [~, zu] = max(L, [], 1);
    
    z(unlabeled) = zu;
end

% make output

s.natoms = K;
s.max_atom_id = max_aid;
s.atom_ids = atom_ids;
s.atoms = atoms;
s.atom_counts = intcount(K, z);
s.iatoms = z;
s.labels = s.atom_ids(z);


%% Subfunctions 

function [a,aux] = redraw_atom(amdl, pridist, obs, g, niters)

aux = [];
for t = 1 : niters
    [a, aux] = amdl.posterior_params(pridist, obs, aux, g, 'atom');
end





