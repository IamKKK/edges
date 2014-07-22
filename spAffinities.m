function [A,E,ucm] = spAffinities( S, E, segs )
% Compute superpixel affinities and optionally corresponding edge map.
%
% Computes an m x m affinity matrix A where A(i,j) is the affinity between
% superpixels i and j. A has values in [0,1]. Only affinities between
% spatially nearby superpixels are computed; the rest are set to 0.
%
% The affinity between superpixels is computed using the output of the
% structured edge detector. In edgesDetect, by default local predicted
% segmentation masks are converted to edge maps and the overlapping local
% edge maps are subsequently averaged to produce a soft edge map. Instead,
% the local segmentation masks can be directly used to measure affinity
% between superpixels (or any segments). Details are omitted, but the
% resulting affinity reasonably captures superpixels similarity. There is
% no corresponding publication for this code at this time but please cite
% our edge detection work if you use this code.
%
% Given affinities, a corresponding edge map can be computed by setting the
% edge strength between adjacent superpixels to be one minus the affinity
% between them. The advantage of the resulting superpixel edge map over the
% original edge map is that edges are connected and non-maximum suppression
% is unnecessary. Given reasonable superpixels, the superpixel edges have
% high benchmark scores (ODS/OIS/AP) similar to the edges from edgesDetect.
%
% Finally, given the superpixel edges, the ultrametric contour map (ucm)
% may be computed. This requires the Berkeley ucm code available from:
%  http://www.eecs.berkeley.edu/Research/Projects/CS/vision/grouping/
% Specifically, the file ucm_mean_pb must be compiled and in private/.
% Thresholding a ucm at any value results in a valid segmentation (the same
% is not true of the original edge map). For details see the Berkeley site.
%
% USAGE
%  [A,E] = spAffinities( S, E, segs )
%
% INPUTS
%  S          - [h x w] superpixel label map (S==0 are boundaries)
%  E          - [h x w] edge probability map (output of edgesDetect)
%  segs       - local segmentations (output of edgesDetect)
%
% OUTPUTS
%  A          - [m x m] superpixel affinity matrix
%  E          - [h x w] superpixel edge probability map
%  ucm        - [h x w] ultrametric contour map (segmenation)
%
% EXAMPLE
%
% See also spDemo, spDetect, edgesDetect
%
% Structured Edge Detection Toolbox      Version 3.0
% Copyright 2014 Piotr Dollar.  [pdollar-at-microsoft.com]
% Please email me if you find bugs, or have suggestions or questions!
% Licensed under the MSR-LA Full Rights License [see license.txt]

A = spDetectMex('affinities',S,E,segs);
if(nargout>1), E = spDetectMex('edges',S,A); end
if(nargout>2), ucm = computeUcm( E ); end

end

function ucm = computeUcm( E )
% creates ultrametric contour map from SP contours
if(exist('ucm_mean_pb','file')~=3),
  warning('ucm code not found, please see help.'); end
E = upsampleEdges(E);
S=bwlabel(E==0,8); S=S(2:2:end,2:2:end)-1;
S(end,:)=S(end-1,:); S(:,end)=S(:,end-1);
E(end+1,:)=E(end,:); E(:,end+1)=E(:,end);
ucm=ucm_mean_pb(E,S); ucm=ucm(1:2:end-2,1:2:end-2);
end

function E = upsampleEdges( E0 )
% upsample E by factor of two while mostly keeping edges thin
[h,w]=size(E0); h=h*2; w=w*2; E=zeros(h,w); E(1:2:h-1,1:2:w-1)=E0;
E(1:2:h-1,2:2:w-2)=min(E0(:,1:end-1),E0(:,2:end)); E(h,:)=E(h-1,:);
E(2:2:h-2,1:2:w-1)=min(E0(1:end-1,:),E0(2:end,:)); E(:,w)=E(:,w-1);
% remove single pixel segments created by thick edges in E0 (2x2 blocks)
A=single(ones(2))/4; A=conv2(single(E0>0),A)==1; [xs,ys]=find(A);
for i = 1:length(xs)
  x=(xs(i)-1)*2; y=(ys(i)-1)*2; es=ones(2,4)+1;
  if(x>2   && y>2  ), es(:,1)=[E(x-2,y-1) E(x-1,y-2)]; end
  if(x<h-2 && y>2  ), es(:,2)=[E(x+2,y-1) E(x+1,y-2)]; end
  if(x<h-2 && y<w-2), es(:,3)=[E(x+2,y+1) E(x+1,y+2)]; end
  if(x>2   && y<w-2), es(:,4)=[E(x-2,y+1) E(x-1,y+2)]; end
  [e,j]=min(max(es));
  if(j==1 || j==4), x1=x-1; else x1=x+1; end
  if(j==1 || j==2), y1=y-1; else y1=y+1; end
  E(x,y1)=e; E(x1,y)=e; E(x1,y1)=e;
  if(es(1,j)<es(2,j)), E(x,y1)=0; else E(x1,y)=0; end
end
end
