  function [Ke,fe]=plante(ex,ey,ep,D,eq)
% Ke=plante(ex,ey,ep,D)
% [Ke,fe]=plante(ex,ey,ep,D,eq)
%-------------------------------------------------------------
% PURPOSE
%  Calculate the stiffness matrix for a triangular plane stress
%  or plane strain element.
%
% INPUT:  ex = [x1 x2 x3]         element coordinates
%         ey = [y1 y2 y3]
%         or
%         ex = [x11 x12 x13;      one row of coordinates per element,
%               ...                all N elements are treated in one call
%               xN1 xN2 xN3]
%         ey = [y11 y12 y13;
%               ...
%               yN1 yN2 yN3]
% 
%         ep = [ptype t ]         ptype: analysis type
%                                 t: thickness
% 
%         D                       constitutive matrix
%
%         eq = [bx;               bx: body force x-dir
%               by]               by: body force y-dir
%
% OUTPUT: Ke : element stiffness matrix (6 x 6) for a single element,
%              (6N x 6) when ex and ey contain N elements, the 6 x 6
%              block of element e in rows 6*(e-1)+1 : 6*e
%         fe : equivalent nodal forces (6 x 1) for a single element,
%              (6N x 1) when ex and ey contain N elements, stacked in
%              the same element by element order as Ke
%-------------------------------------------------------------

% LAST MODIFIED: GitHub Copilot (deepseek-v4-flash)  2026-11-13
% REVIEWED BY  : Hying
% Change Log (relative to the original implementation by M Ristinmaa):
% 1. Vectorized. ex and ey may now be N x 3 matrices, one row per element,
%    and all N elements are treated in a single call. The element matrices
%    are returned stacked in rows, Ke is 6N x 6 and fe is 6N x 1, which is
%    the layout expected by assem. A single element still returns 6 x 6 and
%    6 x 1, so existing callers are unaffected.
% 2. The element matrix is no longer obtained by inverting the 6 x 6 matrix
%    C (B = B0*inv(C)). The closed form of the constant strain triangle
%    B-matrix is used instead, which only needs the shape function
%    derivatives (b_i, c_i) of the three nodes.
% 3. The 3 x 3 material matrix Dm and the nodal load weights are formed
%    once per call instead of once per element.
% 4. Ke of all elements is built from three outer products,
%    Ke(i,j) = sum(q) Bq(i)*(Dm*B')(q,j), which removes both the element
%    loop and the 9 term double sum of the original loop formulation.
% 5. A degenerate element (zero area) now only returns NaN; the singular
%    matrix warning of the former ]/C operation is gone.
% 6. The plane stress / plane strain treatment of D and the error message
%    for an invalid ptype are unchanged.
% 7. Uses implicit expansion of singleton dimensions, which requires
%    MATLAB R2016b or newer.
%-------------------------------------------------------------

%% Element and material data
ptype=ep(1);                    % 1 = plane stress, 2 = plane strain
t=ep(2);                        % thickness

bx=0.; by=0.; if nargin==5;  bx=eq(1); by=eq(2); end   % body force

%% Accept both a single element (1 x 3) and a set of elements (N x 3)
%  After this, every row of ex/ey holds the three node coordinates of one
%  element and all quantities below are computed for all rows at once.
if isvector(ex);  ex=reshape(ex,1,[]);  end
if isvector(ey);  ey=reshape(ey,1,[]);  end

N=size(ex,1);                   % number of elements

%% Element geometry
x1=ex(:,1); x2=ex(:,2); x3=ex(:,3);
y1=ey(:,1); y2=ey(:,2); y3=ey(:,3);

dA=(x2-x1).*(y3-y1)-(x3-x1).*(y2-y1);   % dA = 2*A, signed area
A=dA/2;                                 % element area

% shape function derivatives, b(:,i) = dNi/dx, c(:,i) = dNi/dy
b=[y2-y3, y3-y1, y1-y2];
c=[x3-x2, x1-x3, x2-x1];

%% Rows of the strain-displacement matrix, without the 1/(2*A) factor
%  B = [b1  0 b2  0 b3  0
%        0 c1  0 c2  0 c3
%       c1 b1 c2 b2 c3 b3]/(2*A)
%  B1 gives eps_x, B2 gives eps_y and B3 gives gamma_xy. Each row is kept
%  as an N x 6 array, one row per element.
z=zeros(N,1);
B1=[b(:,1) z b(:,2) z b(:,3) z];
B2=[z c(:,1) z c(:,2) z c(:,3)];
B3=[c(:,1) b(:,1) c(:,2) b(:,2) c(:,3) b(:,3)];

%% Material matrix (same for all elements, therefore formed only once)
colD=size(D,2);

switch ptype
  case 1                                   % plane stress
    if colD>3                              % 3D D given: condense to 3 x 3
      Cm=inv(D);
      Dm=inv(Cm([1 2 4],[1 2 4]));
    else
      Dm=D;
    end
  case 2                                   % plane strain
    if colD>3                              % 3D D given: take in-plane part
      Dm=D([1 2 4],[1 2 4]);
    else
      Dm=D;
    end
  otherwise
    error('Error ! Check first argument, ptype=1 or 2 allowed')
end

%% Element stiffness matrices, Ke = B'*Dm*B*A*t, for all elements at once
%  Element (i,j) of Ke reads  Ke(i,j) = sum(q) Bq(i)*(Dm*B')(q,j), with Bq
%  being row q of B*2*A. The double sum over p and q is folded into the
%  three vectors T1..T3, so only three outer products remain.
T1=Dm(1,1)*B1+Dm(1,2)*B2+Dm(1,3)*B3;      % row 1 of Dm*B' = Dm(1,:)*B
T2=Dm(2,1)*B1+Dm(2,2)*B2+Dm(2,3)*B3;      % row 2 of Dm*B'
T3=Dm(3,1)*B1+Dm(3,2)*B2+Dm(3,3)*B3;      % row 3 of Dm*B'

Ke=B1.*permute(T1,[1 3 2]) ...    % outer products Bq x Tq, N x 6 x 6
  +B2.*permute(T2,[1 3 2]) ...
  +B3.*permute(T3,[1 3 2]);

% scale with A*t/(2*A)^2 = t/(2*dA), one factor per element
Ke=Ke.*reshape(A*t./dA.^2,N,1,1);

% stack the blocks: N x 6 x 6 -> 6N x 6, the block of element e is placed
% in rows 6*(e-1)+1 : 6*e, i.e. the matrix is ordered element by element
Ke=reshape(permute(Ke,[2 1 3]),6*N,6);

%% Equivalent nodal forces, fe = A/3*[bx by bx by bx by]'*t
fe=(A*t/3)*[bx by bx by bx by]; % N x 1 times 1 x 6 -> N x 6, one row per element
fe=reshape(fe.',6*N,1);         % stacked element by element, same order as Ke
%--------------------------end--------------------------------
