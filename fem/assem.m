function [K_new,f_new] = assem(edof,K,Ke,f,fe)
% K=assem(edof,K,Ke)
% [K,f]=assem(edof,K,Ke,f,fe)
%-------------------------------------------------------------
% PURPOSE
%  Assemble element matrices Ke ( and fe ) into the global
%  stiffness matrix K ( and the global force vector f )
%  according to the topology matrix edof.
%
% INPUT: 
%   edof:      dof topology matrix, one row per element
%     Ke:      element stiffness matrix, either
%              num_elems*ndof x ndof : one ndof x ndof block per element,
%                                      stacked in edof order (this is the
%                                      layout returned by plante for a set
%                                      of elements), or
%              ndof x ndof           : one matrix used for all elements
%     K :      the global stiffness matrix
%     f :      the global force vector
%     fe:      element force vector, either
%              num_elems*ndof x 1 or ndof x num_elems : one vector per
%                                      element, element by element, or
%              ndof x 1              : one vector used for all elements
%
% OUTPUT: 
%   K :        the new global stiffness matrix
%   f :        the new global force vector
%-------------------------------------------------------------

% LAST MODIFIED: GitHub Copilot (deepseek-v4-flash)  2026-11-13
% REVIEWED BY  : Hying
% Change Log (relative to the 2025-12-26 version):
% 1. Ke now also accepts the stacked num_elems*ndof x ndof layout, one
%    ndof x ndof block per element, which is what the vectorized plante
%    returns. A single ndof x ndof matrix is still taken as the matrix of
%    all elements.
% 2. fe accepts num_elems*ndof x 1 and ndof x num_elems with the same
%    element by element ordering, and ndof x 1 for a common force vector.
% 3. The kron/reshape index construction is replaced by repelem/repmat,
%    and all element contributions are passed to a single sparse call, so
%    the assembly stays fully vectorized (no loop over the elements).
% 4. The number of columns of Ke and the number of entries of fe are now
%    checked against edof, with explicit error messages.
%-------------------------------------------------------------
%% Identify input information
num_elems = size(edof,1);           % number of elements to assemble
ndof      = size(edof,2);           % number of dofs per element

[num_K_rows,num_K_cols] = size(K);  % size of the global stiffness matrix
if num_K_rows ~= num_K_cols
    error('The global stiffness matrix K must be a square matrix.');
end

[num_Ke_rows,num_Ke_cols] = size(Ke);
if num_Ke_cols ~= ndof
    error(['The element stiffness matrix Ke must have %d columns to match ' ...
           'edof, but has %d.'],ndof,num_Ke_cols);
end
if num_Ke_rows == num_elems*ndof
    % stacked layout, one block per element, nothing to do
elseif num_Ke_rows == ndof
    % one matrix for all elements
    Ke = repmat(Ke,num_elems,1);
else
    error(['The element stiffness matrix Ke must have %d rows ' ...
           '(num_elems*ndof) or %d rows (ndof), but has %d.'], ...
           num_elems*ndof,ndof,num_Ke_rows);
end

%% Global dof numbers of rows and columns of Ke
% Ke is ordered element by element, so row (e-1)*ndof+i of Ke belongs to
% local dof i of element e, i.e. to the global dof edof(e,i):
row_dof = reshape(edof.',[],1);             % num_elems*ndof x 1, element by element
iK      = repmat(row_dof,1,ndof);           % same global row dof in all columns
% column j of the block of element e is the global dof edof(e,j), so the
% block of element e is made of ndof copies of the row edof(e,:)
jK      = repelem(edof,ndof,1);

%% Assemble global stiffness matrix, duplicate entries are summed by sparse
K_new = K + sparse(iK,jK,Ke,num_K_rows,num_K_cols);

%% Assemble global force vector
if nargin == 5
    fe = fe(:);
    if numel(fe) == ndof
        fe = repmat(fe,num_elems,1);        % common force vector
    elseif numel(fe) ~= num_elems*ndof
        error(['The element force vector fe must have %d or %d entries, ' ...
               'but has %d.'],num_elems*ndof,ndof,numel(fe));
    end
    f_new = f + sparse(row_dof,1,fe,num_K_rows,1);
end
end
