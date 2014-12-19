classdef CocoApi
  % Interface for accessing the Microsoft COCO dataset.
  %
  % Microsoft COCO is a large image dataset designed for object detection,
  % segmentation, and caption generation. CocoApi.m is a Matlab API that
  % assists in loading, parsing and visualizing the annotations in COCO.
  % Please visit http://mscoco.org/ for more information on COCO, including
  % for the data, paper, and tutorials. The exact format of the annotations
  % is also described on the COCO website. For example usage of the CocoApi
  % please see cocoDemo.m. In addition to this API, please download both
  % the COCO images and annotations in order to run the demo.
  %
  % An alternative to using the API is to load the annotations directly
  % into a Matlab struct. This can be achieved via:
  %  data = gason(fileread(annFile));
  % Using the API provides additional utility functions. Note that this API
  % supports both *instance* and *caption* annotations. In the case of
  % captions not all functions are defined (e.g. categories are undefined).
  %
  % The following utility functions are provided:
  %  CocoApi    - Load annotation file and prepare data structures.
  %  getAnnIds  - Get annotation ids that satisfy given filter conditions.
  %  getCatIds  - Get category ids corresponding to category names.
  %  getCatNms  - Get category names corresponding to category ids.
  %  getImgIds  - Get image ids that satisfy given filter conditions.
  %  loadAnns   - Load annotations with the specified ids.
  %  loadImg    - Load image with the specified id.
  %  showAnns   - Display the specified annotations.
  % Help on each functions can be accessed by: "help CocoApi>function".
  %
  % See also cocoDemo, CocoApi>CocoApi, CocoApi>getAnnIds,
  % CocoApi>getCatIds, CocoApi>getCatNms, CocoApi>getImgIds,
  % CocoApi>loadAnns, CocoApi>loadImg, CocoApi>showAnns
  %
  % Microsoft COCO Toolbox.      Version 0.90
  % Data, paper, and tutorials available at:  http://mscoco.org/
  % Code written by Piotr Dollar and Tsung-Yi Lin, 2014.
  % Licensed under the Simplified BSD License [see private/bsd.txt]
  
  properties
    imgDir  % directory containing images
    data    % COCO annotation data
    inds    % data structures for fast access
  end
  
  methods
    function coco = CocoApi( imgDir, annFile )
      % Load annotation file and prepare data structures.
      %
      % USAGE
      %  coco = CocoApi( imgDir, annFile )
      %
      % INPUTS
      %  imgDir    - directory containing images
      %  annFile   - string specifying annotation file name
      %
      % OUTPUTS
      %  coco      - initialized coco object
      fprintf('Loading and preparing annotations... '); clk=clock;
      c=coco; c.imgDir=imgDir; c.data=gason(fileread(annFile));
      if( strcmp(c.data.type,'instances') )
        anns = c.data.instances; cats = c.data.categories;
        c.inds.annCatIds = [anns.category_id];
        c.inds.annAreas = [anns.area];
        c.inds.catNmsToIds = containers.Map({cats.name},[cats.id]);
        c.inds.catIdsToNms = containers.Map([cats.id],{cats.name});
      elseif( strcmp(c.data.type,'captions') )
        anns = c.data.captions;
      end
      c.inds.imgIds = [c.data.images.id]; t=c.inds.imgIds;
      c.inds.imgIdsMap = containers.Map(t,1:length(t));
      c.inds.annIds = [anns.id]; t=c.inds.annIds;
      c.inds.annIdsMap = containers.Map(t,1:length(t));
      c.inds.annImgIds = [anns.image_id];
      c.inds.imgAnnIdsMap = makeImgAnnIdsMap( c.inds );
      fprintf('DONE (t=%0.2fs).\n',etime(clock,clk)); coco=c;
      
      function map = makeImgAnnIdsMap( inds )
        % Find map from imgIds to annIds associated with each imgId.
        is = values(inds.imgIdsMap,num2cell(inds.annImgIds));
        is=[is{:}]; m=length(is); n=length(inds.imgIds); k=zeros(1,n);
        for i=1:m, j=is(i); k(j)=k(j)+1; end; a=zeros(n,max(k)); k(:)=0;
        for i=1:m, j=is(i); k(j)=k(j)+1; a(j,k(j))=inds.annIds(i); end
        map = containers.Map('KeyType','double','ValueType','any');
        for j=1:n, map(inds.imgIds(j))=a(j,1:k(j)); end
      end
    end
    
    function cats = getCatNms( coco, ids )
      % Get category names corresponding to category ids.
      %
      % USAGE
      %  cats = coco.getCatNms( [ids] )
      %
      % INPUTS
      %  ids        - [optional] integer ids specifying category
      %
      % OUTPUTS
      %  cats       - string array of category names
      if(nargin<=1), cats=values(coco.inds.catIdsToNms);
      else cats=values(coco.inds.catIdsToNms,num2cell(ids)); end
    end
    
    function ids = getCatIds( coco, cats )
      % Get category ids corresponding to category names.
      %
      % USAGE
      %  ids = coco.getCatIds( [cats] )
      %
      % INPUTS
      %  cats       - [optional] cell array of category names
      %
      % OUTPUTS
      %  ids        - integer array of category ids
      if(nargin<=1), ids=cell2mat(values(coco.inds.catNmsToIds));
      else ids=cell2mat(values(coco.inds.catNmsToIds,cats)); end
    end
    
    function ids = getImgIds( coco, varargin )
      % Get image ids that satisfy given filter conditions.
      %
      % USAGE
      %  ids = coco.getImgIds( params )
      %
      % INPUTS
      %  params     - filtering parameters (struct or name/value pairs)
      %               setting any filter to [] skips that filter
      %   .imgIds     - [] get imgs for given ids
      %   .catIds     - [] get imgs with all given cats
      %
      % OUTPUTS
      %  ids        - integer array of image ids
      p = getPrmDflt(varargin,{'imgIds',[],'catIds',[]},1);
      ids = coco.inds.imgIds;
      if(~isempty(p.imgIds)), ids=intersect(ids,p.imgIds); end
      for i=1:length(p.catIds), ids=intersect(ids,unique(...
          coco.inds.annImgIds(coco.inds.annCatIds==p.catIds(i)))); end
    end
    
    function ids = getAnnIds( coco, varargin )
      % Get annotation ids that satisfy given filter conditions.
      %
      % USAGE
      %  ids = coco.getAnnIds( params )
      %
      % INPUTS
      %  params     - filtering parameters (struct or name/value pairs)
      %               setting any filter to [] skips that filter
      %   .imgIds     - [] get anns for given imgs
      %   .catIds     - [] get anns for given cats
      %   .areaRng    - [] get anns for given area range (e.g. [0 inf])
      %
      % OUTPUTS
      %  ids        - integer array of annotation ids
      p = getPrmDflt(varargin,{'imgIds',[],'catIds',[],'areaRng',[]},1);
      if( length(p.imgIds)==1 )
        ids = coco.inds.imgAnnIdsMap(p.imgIds); K = true(1,length(ids));
        anns = coco.loadAnns(ids); if(isempty(anns)), return; end
        if(~isempty(p.catIds)), K = K & ...
            ismember( [anns.category_id], p.catIds ); end
        if(~isempty(p.areaRng)), areas=[anns.area]; K = K & ...
            areas>=p.areaRng(1) & areas<=p.areaRng(2); end
      else
        ids = coco.inds.annIds; K = true(1,length(ids));
        if(~isempty(p.imgIds)), K = K & ...
            ismember( coco.inds.annImgIds, p.imgIds ); end
        if(~isempty(p.catIds)), K = K & ...
            ismember( coco.inds.annCatIds, p.catIds ); end
        if(~isempty(p.areaRng)), areas=coco.inds.annAreas; K = K & ...
            areas>=p.areaRng(1) & areas<=p.areaRng(2); end
      end
      ids=ids(K);
    end
    
    function I = loadImg( coco, id )
      % Load image with the specified id.
      %
      % USAGE
      %  I = coco.loadImg( id )
      %
      % INPUTS
      %  id         - integer id specifying image
      %
      % OUTPUTS
      %  I          - loaded image
      img = coco.data.images(coco.inds.imgIdsMap(id));
      I = imread([coco.imgDir filesep img.file_name]);
    end
    
    function anns = loadAnns( coco, ids )
      % Load annotations with the specified ids.
      %
      % USAGE
      %  anns = coco.loadAnns( ids )
      %
      % INPUTS
      %  ids        - integer id specifying annotations
      %
      % OUTPUTS
      %  anns       - loaded annotations
      ids = values(coco.inds.annIdsMap,num2cell(ids));
      if( strcmp(coco.data.type,'instances') )
        anns = coco.data.instances([ids{:}]);
      elseif(strcmp( coco.data.type,'captions') )
        anns = coco.data.captions([ids{:}]);
      end
    end
    
    function hs = showAnns( coco, anns )
      % Display the specified annotations.
      %
      % USAGE
      %  hs = coco.showAnns( anns )
      %
      % INPUTS
      %  anns       - annotations to display
      %
      % OUTPUTS
      %  hs         - handles to segment graphic objects
      n=length(anns); if(n==0), return; end
      if( strcmp(coco.data.type,'instances') )
        S={anns.segmentation}; hs=zeros(10000,1); k=0; hold on;
        for i=1:n, clr=rand(1,3); for j=1:length(S{i}), k=k+1; ...
              hs(k)=fill(S{i}{j}(1:2:end),S{i}{j}(2:2:end),clr); end; end
        hs=hs(1:k); set(hs,'FaceAlpha',.4,'LineWidth',3); hold off;
      elseif( strcmp(coco.data.type,'captions') )
        S={anns.caption};
        for i=1:n, S{i}=[int2str(i) ') ' S{i} '\newline']; end
        S=[S{:}]; title(S,'FontSize',12);
      end
      hold off;
    end
  end
  
end
