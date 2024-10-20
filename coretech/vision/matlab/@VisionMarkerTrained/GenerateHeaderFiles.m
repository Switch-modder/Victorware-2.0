function [decisionTreeString, markerDefString] = GenerateHeaderFiles(varargin)

writeFiles = false;
projectRoot = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..', '..');
markerDefFile = 'coretech/vision/shared/MarkerCodeDefinitions.h';
decisionTreeFile = 'coretech/vision/robot/visionMarkerDecisionTrees.h';
probeTree = VisionMarkerTrained.ProbeTree;
if iscell(probeTree)
  labels = probeTree{1}.labels;
else
  labels = probeTree.labels;
end

numFractionalBits = 15;

parseVarargin(varargin{:});

decisionTreeString = sprintf( [...
    '// Autogenerated by VisionMarkerTrained.%s() on %s\n\n' ...
    '// NOTE: (X,Y) probe locations are stored as SQ%d.%d\n\n' ...
    '// Each tree is just an array of nodes, with one big one for the multi-class\n' ...
    '// decision, and N smaller one-vs-all tree for "independently" verifying the\n' ...
    '// decision reached by the multi-class tree.\n\n' ...
    '#ifndef _ANKICORETECHEMBEDDED_VISION_FIDUCIAL_MARKER_DECISION_TREE_H_\n' ...
    '#define _ANKICORETECHEMBEDDED_VISION_FIDUCIAL_MARKER_DECISION_TREE_H_\n\n' ...
    '#include "coretech/vision/robot/decisionTree_vision.h"\n\n' ...
    '#include "coretech/vision/shared/MarkerCodeDefinitions.h"\n\n' ...
    'namespace Anki {\n' ...
    'namespace Embedded {\n' ...
    'namespace VisionMarkerDecisionTree {\n\n' ...
    '#define TREE_NUM_FRACTIONAL_BITS %d\n\n' ...
    '// Leaf labels, which are 16 bits, have first bit set to 1\n' ...
    '#define LEAF_MASK 0x8000\n' ...
    '#define MAKE_LEAF(__VALUE__) (static_cast<u16>(__VALUE__) | LEAF_MASK)\n', ...
    '#define READ_LEAF(__LEAF__) (__LEAF__ & (~LEAF_MASK))\n\n'], ...
    mfilename, datestr(now), 15-numFractionalBits, numFractionalBits, numFractionalBits);

%% Probe point pattern

numPoints = length(VisionMarkerTrained.ProbePattern.x);
x_str = cell(1, numPoints);
y_str = cell(1, numPoints);

for i_pt = 1:numPoints
    x = VisionMarkerTrained.ProbePattern.x(i_pt);
    x_str{i_pt} = sprintf('  %5d, // X[%d] = %.4f\n', ...
        FixedPoint(x, numFractionalBits), i_pt, x);
    
    y = VisionMarkerTrained.ProbePattern.y(i_pt);
    y_str{i_pt} = sprintf('  %5d, // Y[%d] = %.4f\n', ...
        FixedPoint(y, numFractionalBits), i_pt, y);
end
        
decisionTreeString = [decisionTreeString sprintf([ ...
    '// Note: the probe points included the center (0,0) point\n' ...
    'const u32 NUM_PROBE_POINTS = %d;\n' ...
    'const s16 ProbePoints_X[NUM_PROBE_POINTS] = {\n' ...
    '%s' ...
    '};\n' ...
    'const s16 ProbePoints_Y[NUM_PROBE_POINTS] = {\n' ...
    '%s' ...
    '};\n\n'], ...
    numPoints, [x_str{:}], [y_str{:}])];


%% Threshold Probe Locations

numProbes = length(VisionMarkerTrained.BrightProbes.x);
assert(length(VisionMarkerTrained.DarkProbes.x)==numProbes, ...
    'Must have same number of dark and bright probes.');

dark_xStr = cell(1, numProbes);
dark_yStr = cell(1, numProbes);

bright_xStr = cell(1, numProbes);
bright_yStr = cell(1, numProbes);

for i = 1:numProbes
    dark_xStr{i} = sprintf('  %5d, // X = %.4f\n', ...
        FixedPoint(VisionMarkerTrained.DarkProbes.x(i), numFractionalBits), ...
        VisionMarkerTrained.DarkProbes.x(i));
    dark_yStr{i} = sprintf('  %5d, // Y = %.4f\n', ...
        FixedPoint(VisionMarkerTrained.DarkProbes.y(i), numFractionalBits), ...
        VisionMarkerTrained.DarkProbes.x(i));
    
    bright_xStr{i} = sprintf('  %5d, // X = %.4f\n', ...
        FixedPoint(VisionMarkerTrained.BrightProbes.x(i), numFractionalBits), ...
        VisionMarkerTrained.BrightProbes.x(i));
    bright_yStr{i} = sprintf('  %5d, // Y = %.4f\n', ...
        FixedPoint(VisionMarkerTrained.BrightProbes.y(i), numFractionalBits), ...
        VisionMarkerTrained.BrightProbes.x(i));
end

decisionTreeString = [decisionTreeString sprintf([ ...
    'const u32 NUM_THRESHOLD_PROBES = %d;\n' ...
    'const s16 ThresholdDarkProbe_X[NUM_THRESHOLD_PROBES] = {\n' ...
    '%s' ...
    '};\n\n' ...
    'const s16 ThresholdDarkProbe_Y[NUM_THRESHOLD_PROBES] = {\n' ...
    '%s' ...
    '};\n\n' ...
    'const s16 ThresholdBrightProbe_X[NUM_THRESHOLD_PROBES] = {\n' ...
    '%s' ...
    '};\n\n'...
    'const s16 ThresholdBrightProbe_Y[NUM_THRESHOLD_PROBES] = {\n' ...
    '%s' ...
    '};\n\n'], ...
    numProbes, [dark_xStr{:}], [dark_yStr{:}], [bright_xStr{:}], [bright_yStr{:}])];


%% Enums and LUTs
numLabels = length(labels);

enumString          = cell(1, numLabels);
enumString_oriented = cell(1, numLabels);
labelNames          = cell(1, numLabels); % same as enumString_oriented without extra () or ,
enumMappingString   = cell(1, numLabels);
reorderingString    = cell(1, numLabels);
maxDepthString      = cell(1, numLabels);
numNodesString      = cell(1, numLabels);
treePtrString       = cell(1, numLabels);
orientationString   = cell(1, numLabels);

for i_label = 1:numLabels
    
    % The oriented enums are the raw decision tree labels (if they don't
    % have an underscore, add _000 to the end)
    enumName_oriented = labels{i_label};
    if any(strcmp(enumName_oriented, {'ALL_WHITE', 'ALL_BLACK'}))
        % special case
        % TODO: adjust training to change these special labels to ALLWHITE and ALLBLACK
        underscoreIndex = [];
    else
        underscoreIndex = find(enumName_oriented == '_');
        if strncmpi(enumName_oriented, 'inverted_', 9)
            % Ignore the first underscore found if this is
            % an inverted code name
            underscoreIndex(1) = [];
        end
    end
    if isempty(underscoreIndex) 
       enumName_oriented = [enumName_oriented '_000'];  %#ok<AGROW>
       underscoreIndex = length(enumName_oriented)-3;
    end
    labelNames{i_label} = sprintf('MARKER_%s', upper(enumName_oriented));
    enumString_oriented{i_label} = sprintf('  %s', labelNames{i_label});
    %enumString_oriented_quoted{i_label} = sprintf('  "%s",\n', labelNames{i_label});
    
    % The unoriented enums strip off the _QQQ angle off the end
    enumName = sprintf('MARKER_%s', upper(enumName_oriented(1:(underscoreIndex-1))));
    enumString{i_label} = sprintf('%s', enumName);
    %enumString_quoted{i_label} = sprintf('  "%s",\n', enumName);
    
    % Map oriented to unoriented
    enumMappingString{i_label} = ['Vision::' enumString{i_label}];
    
    % Reorient the corners accroding to the orientation.  Using this will
    % result in the first and third corners being the top side.
    reorder = [1 3; 2 4]; % canonical corner ordering
    orientationAngleStr = enumName_oriented((underscoreIndex+1):end);
    switch(orientationAngleStr)
        case '000'
            % nothing to do
        case '090'
            reorder = rot90(rot90(rot90(reorder)));
            %reorder = rot90(reorder);
        case '180'
            reorder = rot90(rot90(reorder));
        case '270'
            %reorder = rot90(rot90(rot90(reorder)));
            reorder = rot90(reorder);
        otherwise
            error('Unrecognized angle string "%s"', angleStr);
    end
    reorderingString{i_label} = sprintf('  {%d,%d,%d,%d},\n', reorder(:)-1);
    
    orientationString{i_label} = sprintf('    %f,\n', str2double(orientationAngleStr));
    
    maxDepthString{i_label} = sprintf('  MAX_DEPTH_VERIFY_%d,\n', i_label-1);

    numNodesString{i_label} = sprintf('  NUM_NODES_VERIFY_%d,\n', i_label-1);
    
    treePtrString{i_label} = sprintf('  VerifyNodes_%d,\n', i_label-1);    
    
end % FOR each label
        
% Create enumerate marker IDs, oriented and unoriented, and a mapping
% between them
decisionTreeString = [decisionTreeString sprintf([...
    'enum OrientedMarkerLabel {\n' ....
    '%s' ...
    '  NUM_MARKER_LABELS_ORIENTED,\n' ...
    '  MARKER_UNKNOWN = NUM_MARKER_LABELS_ORIENTED\n' ...
    '};\n\n'], sprintf('%s,\n', enumString_oriented{:}))];

decisionTreeString = [decisionTreeString sprintf([ ...
    'const char * const OrientedMarkerLabelStrings[NUM_MARKER_LABELS_ORIENTED] = {\n' ...
    '%s' ...
    '};\n\n'], sprintf('"%s",\n', enumString_oriented{:}))];
      
decisionTreeString = [decisionTreeString sprintf([ ...
    'const u32 CornerReorderLUT[NUM_MARKER_LABELS_ORIENTED][4] = {\n' ...
    '%s' ...
    '};\n\n'], [reorderingString{:}])];


%% Multiclass tree
if ~iscell(probeTree)
  probeTree = {probeTree};
end

numTrees = length(probeTree);
arrays = cell(1, numTrees);
maxDepths = cell(1, numTrees);
numNodes = cell(1,numTrees);
treeNames = cell(1, numTrees);
leafLabels = cell(1, numTrees);
% leafNodeArrayNames = cell(1, numTrees);
for iTree = 1:numTrees
  [arrays{iTree},maxDepths{iTree},leafLabels{iTree}] = CreateTreeArray(probeTree{iTree}, VisionMarkerTrained.ProbeRegion, VisionMarkerTrained.ProbeParameters.GridSize);
  numNodes{iTree} = length(arrays{iTree});
  
  treeNames{iTree} = sprintf('  MultiClassNodes_%d,\n', iTree);
  
  arrayString = GetArrayString(arrays{iTree}, numFractionalBits, labelNames, leafLabels{iTree}, false);
  
  decisionTreeString = [decisionTreeString sprintf([ ...
    'const u32 NUM_NODES_MULTICLASS_%d = %d;\n' ...
    'const u32 MAX_DEPTH_MULTICLASS_%d = %d;\n' ...
    'const FiducialMarkerDecisionTree::Node MultiClassNodes_%d[NUM_NODES_MULTICLASS_%d] = {\n' ...
    '%s' ...
    '};\n\n'], ...
    iTree, numNodes{iTree}, ...
    iTree, maxDepths{iTree}, ...
    iTree, iTree, ...
    [arrayString{:}])];
  
%   leafNodeArrayNames{iTree} = sprintf('  LeafLabels_%d,\n', iTree);
%   
%   decisionTreeString = [decisionTreeString sprintf([ ...
%       'const u32 NUM_LEAF_LABELS_%d = %d;\n' ...
%       'const u16 LeafLabels_%d[NUM_LEAF_LABELS_%d] = {\n', ...
%       '%s' ...
%       '};\n\n'], ...
%       iTree, length(leafLabels{iTree}), iTree, iTree, sprintf('%d,', leafLabels{iTree}-1))];
end

decisionTreeString = [decisionTreeString sprintf([ ...
  'const u32 NUM_TREES = %d;\n' ...
  'const u32 NUM_NODES_MULTICLASS[NUM_TREES] = {%s};\n' ...
  'const u32 MAX_DEPTH_MULTICLASS[NUM_TREES] = {%s};\n' ...
  'const FiducialMarkerDecisionTree::Node* const MultiClassNodes[NUM_TREES] = {\n' ...
  '%s' ...
  '};\n\n'], ...
  numTrees, ...
  sprintf('%d,', numNodes{:}), ...
  sprintf('%d,', maxDepths{:}), ...
  [treeNames{:}])];

% numLeafLabels = cellfun(@length, leafLabels, 'UniformOutput', false);
% decisionTreeString = [decisionTreeString sprintf([...
%   'const u32 NUM_LEAF_LABELS[NUM_TREES] = {%s};\n' ...
%   'const u16* LeafLabels[NUM_TREES] = {\n' ...
%   '%s' ...
%   '};\n\n'], ...
%   sprintf('%d,', numLeafLabels{:}), ...
%   [leafNodeArrayNames{:}])];
      

%% Verification trees
if length(probeTree) == 1 && ~isobject(probeTree{1})
  if all(isfield(probeTree{1}, {'verifyTreeRed', 'verifyTreeBlack'}))
    % "Red" Tree
    [array,maxDepth,leafLabels] = CreateTreeArray(probeTree{1}.verifyTreeRed);
    
    arrayString = GetArrayString(array, numFractionalBits, labelNames, leafLabels, true);
    
    decisionTreeString = [decisionTreeString sprintf([ ...
      'const u32 NUM_NODES_VERIFY_RED = %d;\n' ...
      'const u32 MAX_DEPTH_VERIFY_RED = %d;\n' ...
      'const FiducialMarkerDecisionTree::Node VerifyRedNodes[NUM_NODES_VERIFY_RED] = {\n' ...
      '%s' ...
      '};\n\n'], ...
      length(array), maxDepth, [arrayString{:}])];
    
    decisionTreeString = [decisionTreeString sprintf([ ...
      'const u32 NUM_LEAF_LABELS_RED = %d;\n' ...
      'const u16 VerifyRedLeafLabels[NUM_LEAF_LABELS_RED] = {\n', ...
      '%s' ...
      '};\n\n'], ...
      length(leafLabels), sprintf('%d,', leafLabels-1))];
    
    % "Black" Tree
    [array,maxDepth,leafLabels] = CreateTreeArray(probeTree{1}.verifyTreeBlack);
    
    arrayString = GetArrayString(array, numFractionalBits, labelNames, leafLabels, true);
    
    decisionTreeString = [decisionTreeString sprintf([ ...
      'const u32 NUM_NODES_VERIFY_BLACK = %d;\n' ...
      'const u32 MAX_DEPTH_VERIFY_BLACK = %d;\n' ...
      'const FiducialMarkerDecisionTree::Node VerifyBlackNodes[NUM_NODES_VERIFY_BLACK] = {\n' ...
      '%s' ...
      '};\n\n'], ...
      length(array), maxDepth, [arrayString{:}])];
    
    decisionTreeString = [decisionTreeString sprintf([ ...
      'const u32 NUM_LEAF_LABELS_BLACK = %d;\n' ...
      'const u16 VerifyBlackLeafLabels[NUM_LEAF_LABELS_BLACK] = {\n', ...
      '%s' ...
      '};\n\n'], ...
      length(leafLabels), sprintf('%d,', leafLabels-1))];
    
  else
    assert(isfield(probeTree, 'verifiers'), ...
      ['If not using red/black verification trees, assuming there ' ...
      'are one-vs-all trees in a "verifiers" field.']);
    
    numVerifiers = length(probeTree.verifiers);
    assert(numLabels==numVerifiers, ...
      'There should be a label name for each verification tree.');
    
    for i_label = 1:numVerifiers
      
      [array,maxDepth] = CreateTreeArray(probeTree.verifiers(i_label));
      
      arrayString = GetArrayString(array, numFractionalBits, {'MARKER_UNKNOWN', labelNames{i_label}});
      
      decisionTreeString = [decisionTreeString sprintf([ ...
        'const u32 NUM_NODES_VERIFY_%d = %d;\n' ...
        'const u32 MAX_DEPTH_VERIFY_%d = %d;\n' ...
        'const FiducialMarkerDecisionTree::Node VerifyNodes_%d[NUM_NODES_VERIFY_%d] = {\n' ...
        '%s' ...
        '};\n\n'], ...
        i_label-1, length(array), ...
        i_label-1, maxDepth, ...
        i_label-1, i_label-1, ...
        [arrayString{:}])]; %#ok<AGROW>
    end
    
    
    decisionTreeString = [decisionTreeString sprintf([ ...
      '// For convenience, store pointers to the verification trees (and their max\n' ...
      '// depths and num nodes) in arrays, indexable by marker type:\n\n' ...
      'const u32 MAX_DEPTH_VERIFY[NUM_MARKER_LABELS_ORIENTED] = {\n' ...
      '%s' ...
      '};\n\n' ...
      'const u32 NUM_NODES_VERIFY[NUM_MARKER_LABELS_ORIENTED] = {\n' ...
      '%s' ...
      '};\n\n'], [maxDepthString{:}], [numNodesString{:}])];
    
    decisionTreeString = [decisionTreeString sprintf([...
      'const FiducialMarkerDecisionTree::Node* const VerifyNodes[NUM_MARKER_LABELS_ORIENTED] = {\n', ...
      '%s' ...
      '};\n\n'], [treePtrString{:}])];
    
  end % if red/black verification or one-vs-all
end

%% Marker Type Definitions
% Different file now!
markerDefString = sprintf([ ...
    '// Autogenerated by VisionMarkerTrained.%s() on %s\n\n' ...
    '#ifndef ANKI_COZMO_VISIONMARKERTYPES_H\n' ...
    '#define ANKI_COZMO_VISIONMARKERTYPES_H\n\n' ...
    'namespace Anki {\n' ...
    '  namespace Vision {\n\n'], ...
    mfilename, datestr(now));
    
enumString = unique(enumString);
enumStringsWithValues = [enumString(:) num2cell((0:length(enumString)-1)')]';

markerDefString = [markerDefString sprintf([ ...
    '    enum MarkerType {\n' ...
    '%s' ...
    '      NUM_MARKER_TYPES,\n' ...
    '      MARKER_UNKNOWN = NUM_MARKER_TYPES\n' ...
    '    };\n\n'], sprintf('      %s = %d,\n', enumStringsWithValues{:}))];

markerDefString = [markerDefString sprintf([ ...
    '    const char * const MarkerTypeStrings[NUM_MARKER_TYPES+1] = {\n' ...
    '%s' ...
    '      "MARKER_UNKNOWN"\n' ...
    '    };\n\n'], sprintf('      "%s",\n', enumString{:}))];

repeatedEnumString = [enumString(:) enumString(:)]';
markerDefString = [markerDefString sprintf([ ...
    '    const std::map<std::string, Vision::MarkerType> StringToMarkerType = {\n' ...
    '%s' ...
    '      {"MARKER_UNKNOWN", MARKER_UNKNOWN}\n' ...
    '    };\n'], sprintf('      {"%s", %s},\n', repeatedEnumString{:}))];

markerDefString = [markerDefString sprintf([ ...
  '  } // namespace Vision\n' ...
  '} // namespace Anki\n\n' ...
  '#endif // ANKI_COZMO_VISIONMARKERTYPES_H\n\n'])];
 
%% Move back to DTree defs
decisionTreeString = [decisionTreeString sprintf([ ...
    'const Vision::MarkerType RemoveOrientationLUT[NUM_MARKER_LABELS_ORIENTED] = {\n' ...
    '%s' ...
    '};\n\n'], sprintf('  %s,\n', enumMappingString{:}))];

decisionTreeString = [decisionTreeString sprintf([ ...
    'const f32 ObservedOrientationLUT[NUM_MARKER_LABELS_ORIENTED] = {\n' ...
    '%s' ...
    '};\n\n'], [orientationString{:}])];

decisionTreeString = [decisionTreeString sprintf([ ...
    '} // namespace VisionMarkerDecisionTree\n' ...
    '} // namespace Embedded\n' ...
    '} // namespace Anki\n\n' ...
    '#endif // _ANKICORETECHEMBEDDED_VISION_FIDUCIAL_MARKER_DECISION_TREE_H_\n'])];



if writeFiles 
   
    decisionTreeFile = fullfile(projectRoot, decisionTreeFile);
    fid = fopen(decisionTreeFile, 'wt');
    if fid == -1
        error('Could not open "%s" for writing decision tree file.', decisionTreeFile);
    else
        fprintf(fid, '%s', decisionTreeString);
        fclose(fid);
        fprintf('Wrote decision tree definition to "%s".\n', decisionTreeFile);
    end
    
    markerDefFile = fullfile(projectRoot, markerDefFile);
    fid = fopen(markerDefFile, 'wt');
    if fid == -1
        error('Could not open "%s" for writing marker definition file.', markerDefFile);
    else
        fprintf(fid, '%s', markerDefString);
        fclose(fid);
        fprintf('Wrote marker definitions to "%s".\n', markerDefFile);
    end
    
end % IF writeFiles

% if nargout==0
%     clipboard('copy', decisionTreeString);
%     fprintf('\nCopied header file to clipboard.\n\n');
%     clear outputString;
% end

%sprintf('Maximum differences with %d fractional bits:\n\nTheoretical: %f\n\nMeasured:\nXProbes: %f (%f percent)\nYProbes: %f (%f percent)\nProbeWeights: %f (%f percent)\n',...
%    numFractionalBits, 1/(2^(numFractionalBits+1)), maxX, maxXPercent, maxY, maxYPercent, maxP, maxPPercent)
    
end % FUNCTION GenerateHeaderFile()

function fixedPt = FixedPoint(value, numFractionalBits)

if isempty(value)
    fixedPt = 0;
else
    fixedPt = int32(round(2^numFractionalBits)*value);
end

end % FUNCTION FixedPointHelper()

function arrayString = GetArrayString(array, numFractionalBits, labelNames, leafLabels, allowMultiLabelLeaves)

arrayString = cell(1,length(array));
for i = 1:length(array)
    if ~isempty(array(i).leftIndex)
        leftIndex = array(i).leftIndex-1;
        label = '0';
        assert(leftIndex >= 0, 'Expecting all leftIndexes to be >= 0.');
        assert(leftIndex < 2^16, 'LeftIndex=%d will not fit in u16.', leftIndex);
        assert(isempty(array(i).label) || array(i).label==0, 'If left index is given, expecting label to be empty or zero.');
        
        x = FixedPoint(array(i).x, numFractionalBits);
        y = FixedPoint(array(i).y, numFractionalBits);
            
        lineComment = sprintf('// X=%.4f, Y=%.4f', array(i).x, array(i).y);
    end
    
    if ~isempty(array(i).label) 
        leftIndex = 0;
        if array(i).x == array(i).y
            assert(array(i).label > 0, 'Expecting all labels > 0.');
            assert(array(i).label-1 < 2^15, 'Label=%d will not fit in last 15 bits of u16.', label);
            assert(isempty(array(i).leftIndex), 'If label is given, expecting leftIndex to be empty.');
            %label = bitor(uint16(label), LeafMask); % Set first bit to 1
            x = 0;
            y = 0;
            label = sprintf('MAKE_LEAF(%s)', labelNames{array(i).label});
            
            lineComment = sprintf('// Leaf node, label = %s', labelNames{array(i).label});
        else
            
          if allowMultiLabelLeaves
            % X and Y are storing the start and end indices of the labels
            % for this leaf. No fixed point conversion.
            assert(array(i).label < 0, ...
                'Expecting label == -1 for for multi-label leaf.');
            
            x = array(i).x - 1; % -1 for C vs Matlab indexing
            y = array(i).y - 1; % -1 for C vs Matlab indexing
            assert(x >= 0 && x < length(leafLabels), ...
                'Leaf label start index out of bounds.');
            assert(y > 0 && y <= length(leafLabels), ...
                'Leaf label start index out of bounds.');
            
            label = 'MAKE_LEAF(0)';
            lineComment = '// Multi-label leaf node';
          else
            % Use mode of the leaf labels as the label
            x = 0;
            y = 0;
            labelID = mode(leafLabels);
            label = sprintf('MAKE_LEAF(%s)', labelNames{labelID});
            lineComment = sprintf('// Leaf node (originally multi-label), label = %s', labelNames{labelID});
          end
        end
        
        
    end
    
    
    arrayString{i} = sprintf('  {%5d,%5d,%5d, %s}, %s\n', ...
        x, y, ...
        leftIndex, label, ...
        lineComment);
end

end % FUNCTION GetArrayString()

