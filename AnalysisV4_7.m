%% Initialize Clean Workspace and Load All Traces
% Clear previous UIfigures and variables from workspace
ExistingFigs = findall(groot, 'Type', 'figure');
for q = 1:length(ExistingFigs)
    if strcmp(ExistingFigs(q).BeingDeleted,'off') && strcmp(get(ExistingFigs(q),'Tag'),'')
        delete(ExistingFigs(q));
    end
end
clearvars; clc;
format long;

% Prompt user for directory with .txt files
ScreenSize = get(groot, 'ScreenSize');
try
    LoadPath = GetFilePath(ScreenSize);
    if strcmp(LoadPath,"")
        error %#ok<LTARG> 
    end
catch exception
    warning('User cancelled file path selection.')
    clearvars;
    close all;
    return
end

% Create list of all possible files in directory
APs = dir(fullfile(LoadPath, 'AP_*.txt'));
APs = NotASCIISort({APs.name});
PSPs = dir(fullfile(LoadPath, 'PSP_*.txt'));
PSPs = NotASCIISort({PSPs.name});

% Load all traces
[ControlLoadedStruct, MicrowaveLoadedStruct] = LoadTraces(LoadPath,APs,PSPs);
Range = length(ControlLoadedStruct) + length(MicrowaveLoadedStruct);
clear APs PSPs;

%% Stablity Analysis
% Show stability preview and trace selection prompt
Fields = {'APVals', 'PSPVals'};
Operations = {@min, @max, @mean, @std};
InputStructs = {'ControlLoadedStruct', 'MicrowaveLoadedStruct'};
OutputPrefixes = {'Control', 'Microwave'};
for q = 1:length(InputStructs)
    InputStruct = eval(InputStructs{q});
    OutputPrefix = OutputPrefixes{q};
    for f = 1:length(Fields)
        Field = Fields{f};
        Vals = cell2mat({InputStruct.(Field)});
        for o = 1:length(Operations)
            Operation = Operations{o};
            FunctionName = func2str(Operation);
            ParametersStruct.([OutputPrefix Field FunctionName 's']) = Operation(Vals);
        end
    end   
    ParametersStruct.([OutputPrefix 'XAxis']) = [InputStruct.Trace];
end
clear f Field Fields FunctionName InputStruct InputStructs o Operation Operations OutputPrefix OutputPrefixes q Vals;
[First, Last, TraceLength] = TraceSelect(ParametersStruct,ScreenSize,Range);
ControlStruct = ControlLoadedStruct(arrayfun(@(x) x.Trace >= First && x.Trace <= Last, ControlLoadedStruct));
MicrowaveStruct = MicrowaveLoadedStruct(arrayfun(@(x) x.Trace >= First && x.Trace <= Last, MicrowaveLoadedStruct));
TraceTime = linspace(0,TraceLength,numel(ControlStruct(1).APVals));

%% Create Access Menu (Converting to OOP in V5)
% Create foundational access menu with disabled buttons
AccessMenu = uifigure('Position',[ScreenSize(3)-round(ScreenSize(3)/6) ScreenSize(4)-round(ScreenSize(4)/1.1) 275 400],'Name','Access Menu','WindowStyle','alwaysontop');
[StartDate,EndDate] = regexp(LoadPath,'\d{2}-\d{2}-\d{4}');
uilabel(AccessMenu,'Text',sprintf('%d traces from %s',Range,LoadPath(StartDate:EndDate)),'Position',[5 380 200 15],'FontWeight','Bold');
uilabel(AccessMenu,'Text',sprintf('Analyzing traces %d to %d',First,Last),'Position',[5 365 200 15],'FontAngle','Italic');
AMSampling = uilabel(AccessMenu,'Text',sprintf('%d Hz sampling rate',length(TraceTime)/TraceLength),'Position',[5 350 200 15]);
AMThreshold = uilabel(AccessMenu,'Text','','Position',[5 335 200 15]);
AMWindowing = uilabel(AccessMenu,'Text','','Position',[5 320 200 15]);
uilabel(AccessMenu,'Text','Processing','Position',[5 295 200 15],'FontWeight','Bold');
AMTraceDispDropdown = uidropdown(AccessMenu, 'Position', [155 275 50 20],'Items', string(First:Last));
AMTraceDisp = uibutton(AccessMenu,'Position', [5 275 150 20], 'Text', 'Display Trace:', 'ButtonPushedFcn', @(btn,event) TraceDisp(AMTraceDispDropdown.Value,ControlStruct,MicrowaveStruct,TraceTime,ScreenSize,0));
AMTraceCheck = uicheckbox(AccessMenu,'Position',[210 275 80 20],'Text','Labeled','Enable','off');
AMStability = uibutton(AccessMenu,'Position', [5 255 150 20], 'Text', 'Trace Stability Check', 'ButtonPushedFcn', @(btn,event) StabilityPlot(ParametersStruct,ScreenSize));
AMRasterC = uibutton(AccessMenu,'Position',[5 235 150 20],'Text','Labeled Control Raster','Enable','off');
AMRasterM = uibutton(AccessMenu,'Position',[5 215 150 20],'Text','Labeled Microwave Raster','Enable','off');
uilabel(AccessMenu,'Text','Statistical Analysis','Position',[5 190 200 15],'FontWeight','Bold');
uilabel(AccessMenu,'Text','Characteristic:','Position',[5 170 100 20]);
AMStatsCharacteristic = uidropdown(AccessMenu, 'Position', [85 170 135 20],'Items', ["AHP Amplitudes","Amplitudes","Durations","Frequencies","Interspike Intervals"],'Enable','off');
uilabel(AccessMenu,'Text','Time Segmentation:','Position',[5 150 110 20]);
AMStatsSegmentation = uidropdown(AccessMenu, 'Position', [115 150 65 20],'Items', ["2.5 s","5 s","10 s"],'Enable','off');
uilabel(AccessMenu,'Text','Type of Figure:','Position',[5 130 100 20]);
AMStatsFigure = uidropdown(AccessMenu,'Position',[90 130 100 20],'Items',["Histograms","Violin Plots"],'Enable','off');
AMStatsEdges = uidropdown(AccessMenu,'Position',[155 110 110 20],'Items',["Outliers","Trimmed","Winsorized"],'Enable','off');
AMStatsDisp = uibutton(AccessMenu,'Position',[5 110 150 20],'Text','Create Figure Plots','Enable','off');
uilabel(AccessMenu,'Text','Visual Analysis','Position',[5 85 200 15],'FontWeight','Bold');
AMRasterProcess = uibutton(AccessMenu,'Position',[5 65 150 20],'Text','Axon Labeling Process','Enable','off');
AMAPCompare = uibutton(AccessMenu,'Position',[5 45 150 20],'Text','Average AP Comparison','Enable','off');
clear ControlLoadedStruct MicrowaveLoadedStruct StartDate EndDate;

%% Trace Modifications
% Define trace polarity
[ControlStruct, MicrowaveStruct] = TracePolarity(TraceTime,ControlStruct,MicrowaveStruct,ScreenSize);
AMTraceDisp.ButtonPushedFcn = @(btn,event) TraceDisp(AMTraceDispDropdown.Value, ControlStruct, MicrowaveStruct, TraceTime, ScreenSize, 0);

% Define noise levels
[Threshold, Average] = TraceDetails(ScreenSize,ControlStruct(1).APVals,TraceTime,TraceLength);
ThresholdExpression = sprintf('Threshold: %0.3e V', Threshold);
ThresholdExpression = regexprep(ThresholdExpression, 'e\+?0*(\d+)', ' x 10^$1');
AMThreshold.Text = regexprep(ThresholdExpression, 'e-(0*)(\d+)', ' x 10^-$2');

% Define data window
[WindowStart, WindowEnd, NewTraceTime, NewTraceLength] = WindowAdjust(MicrowaveStruct,TraceTime,TraceLength,ScreenSize);
AMWindowing.Text = sprintf('%.2fs to %.2fs window of %.1fs',Index2Sec(WindowStart,TraceTime,TraceLength),Index2Sec(WindowEnd,TraceTime,TraceLength),TraceLength);
clear NoisePoints;

%% Spike Sorting
% Identifies spike parameters in window
ControlStruct = SpikeSort(ControlStruct,WindowStart,WindowEnd,TraceTime,TraceLength,Threshold,Average);
MicrowaveStruct = SpikeSort(MicrowaveStruct,WindowStart,WindowEnd,TraceTime,TraceLength,Threshold,Average);

%% Creation of Raster Plots
ControlStruct = TraceBounds(ControlStruct,ScreenSize);
ControlStruct = SecondTraceBounds(ControlStruct,ScreenSize);
AMRasterC.ButtonPushedFcn = @(btn,event) RasterPlotter(ControlStruct,ScreenSize);
AMRasterC.Enable = 'on';

%% MW Second Bounds
MicrowaveStruct = TraceBounds(MicrowaveStruct,ScreenSize);
MicrowaveStruct = SecondTraceBounds(MicrowaveStruct,ScreenSize);
AMRasterM.ButtonPushedFcn = @(btn,event) RasterPlotter(MicrowaveStruct,ScreenSize);
AMRasterM.Enable = 'on';
AMRasterProcess.ButtonPushedFcn = @(btn,event) RasterProcessDisp(MicrowaveStruct,ScreenSize,WindowStart,TraceTime,TraceLength);
AMRasterProcess.Enable = 'on';
AMTraceCheck.Enable = 'on';
AMTraceDisp.ButtonPushedFcn = @(btn,event) TraceDisp(AMTraceDispDropdown.Value, ControlStruct, MicrowaveStruct, TraceTime, ScreenSize, AMTraceCheck.Value);

%% Analysis Options
AMStability.ButtonPushedFcn = @(btn,event) StabilityPlot(ParametersStruct,ScreenSize);
AMTraceDisp.ButtonPushedFcn = @(btn,event) TraceDisp(AMTraceDispDropdown.Value, ControlStruct, MicrowaveStruct, TraceTime, ScreenSize, AMTraceCheck.Value);
AMRasterC.ButtonPushedFcn = @(btn,event) RasterPlotter(ControlStruct,ScreenSize);
AMRasterProcess.ButtonPushedFcn = @(btn,event) RasterProcessDisp(MicrowaveStruct,ScreenSize,WindowStart,TraceTime,TraceLength);
AMStatsCharacteristic.Enable = 'on';
AMStatsSegmentation.Enable = 'on';
AMStatsFigure.Enable = 'on';
AMStatsEdges.Enable = 'on';
AMStatsDisp.ButtonPushedFcn = @(btn,event) StatsDisp(ScreenSize,ControlStruct,MicrowaveStruct,AMStatsFigure.Value,AMStatsSegmentation.Value,NewTraceLength,WindowStart,TraceTime,TraceLength,AMStatsCharacteristic.Value,First,Last,AMStatsEdges.Value);
AMStatsDisp.Enable = 'on';
AMAPCompare.ButtonPushedFcn = @(btn,event) APComparePlot(ScreenSize,ControlStruct,MicrowaveStruct,Average,TraceTime,TraceLength);
AMAPCompare.Enable = 'on';

%% Loading Functions
function SortedData = NotASCIISort(Data)
% Function that sorts filenames in numerical order or structure arrays based on the 'Trace' field
    if iscell(Data)
        [~,Numeric] = cellfun(@fileparts, Data, 'UniformOutput',false);
        Values = str2double(regexprep(Numeric,'[^\d\.]+', ''));
        [~,idx] = sort(Values);
        SortedData = Data(idx);
    elseif isstruct(Data)
        TraceValues = [Data.Trace];
        [~, idx] = sort(TraceValues);
        SortedData = Data(idx);
    else
        error('Input to NotASCIISort must be a cell array of filenames or a structure array.')
    end
end

function [ControlStruct, MicrowaveStruct] = LoadTraces(Path, APNames, PSPNames)
% Function that parallel loads traces
    FirstTrace = str2double(split(extractBetween(APNames{1}, 4, strlength(APNames{1})-4), '_'));
    LastTrace = str2double(split(extractBetween(APNames{end}, 4, strlength(APNames{end})-4), '_'));
    Traces = LastTrace - FirstTrace + 1;
    TempStruct = struct('Trace',[],'APVals',[],'PSPVals',[]);
    
    ControlStruct = repmat(TempStruct, 1, ceil(Traces/2)); % for odd traces
    MicrowaveStruct = repmat(TempStruct, 1, floor(Traces/2)); % for even traces

    LoadingBar = waitbar(0,'Preparing parallel trace load...');
    if isempty(gcp('nocreate'))
        P = parpool('local','IdleTimeout',60,'AttachedFiles',{});
    else
        P = gcp('nocreate');
    end

    futures = parallel.FevalFuture.empty(0, Traces);
    for q = 1:Traces
        futures(q) = parfeval(P, @LoadData, 1, q, FirstTrace, Path, APNames, PSPNames);
    end

    odd_idx = 0;
    even_idx = 0;

    for Idx = 1:Traces
        [CompletedIdx, ResultStruct] = fetchNext(futures);
        if mod(ResultStruct.Trace, 2) == 1
            odd_idx = odd_idx + 1;
            ControlStruct(odd_idx) = ResultStruct;
        else
            even_idx = even_idx + 1;
            MicrowaveStruct(even_idx) = ResultStruct;
        end
        waitbar(CompletedIdx/Traces,LoadingBar,sprintf('Loading traces %d to %d: %d remaining',FirstTrace,LastTrace,LastTrace-FirstTrace+1-CompletedIdx));
    end
    close(LoadingBar)
    ControlStruct = NotASCIISort(ControlStruct);
    MicrowaveStruct = NotASCIISort(MicrowaveStruct);

    function ResultStruct = LoadData(q, FirstTrace, Path, APs, PSPs)
        ResultStruct = struct();
        ResultStruct.Trace = q + FirstTrace - 1;
        ResultStruct.APVals = load([Path '\' APs{ResultStruct.Trace}]);
        ResultStruct.PSPVals = load([Path '\' PSPs{ResultStruct.Trace}]);
    end
end

function FilePath = GetFilePath(ScreenSize)
% Function that creates a selection UI for the convereted waveform file directory
    ExistingCheck = findobj('Name','Loading converted IGOR files');
    if ~isempty(ExistingCheck)
        return
    end
    PromptFig = uifigure('Position',[(ScreenSize(3)-350)/2 (ScreenSize(4)-150)/2 350 150],'Name','Loading convereted IGOR files');
    PromptGrid = uigridlayout(PromptFig,[4,1],'RowHeight',{'fit','fit','fit'});
    uilabel(PromptGrid,'Text','Select folder with .txt converted IGOR waves');
    uibutton(PromptGrid,'Text','Select Folder','ButtonPushedFcn',@(~,~)FolderSelect);
    uibutton(PromptGrid,'Text','Select .nwb File','Enable','off');
    uibutton(PromptGrid,'Text','Cancel','ButtonPushedFcn',@(~,~)SessionEnd,'FontWeight','Bold');
    uiwait(PromptFig)

    function FolderSelect()
        Path = uigetdir('\\engnas.bu.edu\research\eng_research_yanglab\yang lab\Data\A_Mark_MC\Crayfish MW\Experimental Data');
        if Path ~= 0
            FilePath = Path;
            uiresume(PromptFig)
            close(PromptFig)
        else
            SessionEnd();
        end
    end
    function SessionEnd()
        FilePath = '';
        uiresume(PromptFig)
        close(PromptFig)
    end
end

%% Trace Modification Functions 
function [Threshold, Average] = TraceDetails(ScreenSize,APVoltage,TraceTime,TraceLength)
% Function that gets the detection threshold and baseline average of APs
    DetailsFig = uifigure('Position', [(ScreenSize(3)-1000)/2 (ScreenSize(4)-700)/2 1000 700], 'Name', 'Set ');
    Ax = uiaxes(DetailsFig, 'Position', [50 125 900 550]);
    plot(Ax,TraceTime,APVoltage,'Color',[0 0 1]);
    hold(Ax,'on')
    title(Ax, 'Select Key Trace Parameters','FontSize',16,'FontWeight','Bold');
    xlabel(Ax, 'Time (s)','FontSize',13);
    ylabel(Ax, 'Membrane Potential Difference (V)','FontSize',13);
    grid(Ax, 'on');
    Threshold = NaN;
    LeftBound = NaN;
    RightBound = NaN;
    ThresholdLine = [];
    LeftLine = [];
    RightLine = [];
    ThresholdButton = uibutton(DetailsFig,'Position',[200 100 100 20],'Text','Set Threshold','ButtonPushedFcn',@(btn,event)SetLines(btn,'Threshold'));
    ResetThresholdButton = uibutton(DetailsFig,'Position',[200 80 100 20],'Text','Reset Threshold','ButtonPushedFcn',@(btn,event)ResetButtons('Threshold'),'Enable','off');
    ErrorCall = uilabel(DetailsFig,'Position',[200 60 100 20],'Text','','FontColor',[1 0 0]);
    LeftButton = uibutton(DetailsFig,'Position',[700 100 100 20],'Text','Set Left Bound','ButtonPushedFcn',@(btn,event)SetLines(btn,'UpperBound'));
    RightButton = uibutton(DetailsFig,'Position',[700 80 100 20],'Text','Set Right Bound','ButtonPushedFcn',@(btn,event)SetLines(btn,'LowerBound'));
    ResetBoundsButton = uibutton(DetailsFig,'Position',[700 60 100 20],'Text','Reset Bounds','ButtonPushedFcn',@(btn,event)ResetButtons('Bounds'),'Enable','off');
    uibutton(DetailsFig,'Position',[450 30 100 20],'Text','Confirm','ButtonPushedFcn',@(btn,event)ConfirmTraceDetails());
    uiwait(DetailsFig);

    function SetLines(btn,LineType)
        btn.Enable = 'off';
        OriginalText = btn.Text;
        btn.Text = 'Selecting';
        switch LineType
            case 'Threshold'
                ResetThresholdButton.Enable = 'on';
            case {'UpperBound', 'LowerBound'}
                ResetBoundsButton.Enable = 'on';
        end

        Ax.ButtonDownFcn = @(Ax,event) CaptureClick(Ax,event,LineType,btn,OriginalText);
    end

    function CaptureClick(Ax,event,LineType,btn,OriginalText)
        Points = event.IntersectionPoint;
        Ax.ButtonDownFcn = '';
        switch LineType
            case 'Threshold'
                Threshold = Points(2);
                ThresholdLine = yline(Ax,Points(2), 'Color', [.85 0 .85]);  
            case {'UpperBound', 'LowerBound'}
                if strcmp(LineType,'UpperBound')
                    LeftBound = Sec2Index(Points(1),TraceTime,TraceLength);
                    LeftLine = xline(Ax,Points(1),'Color',[.17 .79 .13]);
                else
                    RightBound = Sec2Index(Points(1),TraceTime,TraceLength);
                    RightLine = xline(Ax,Points(1),'Color',[.17 .79 .13]);
                end 
        end
        btn.Text = OriginalText;
    end

    function ResetButtons(ResetLine)
        switch ResetLine
            case 'Threshold'
                Threshold = NaN;
                delete(ThresholdLine);
                ThresholdButton.Enable = 'on';
                ResetThresholdButton.Enable = 'off';
            case 'Bounds'
                LeftBound = NaN;
                RightBound = NaN;
                if isvalid(LeftLine)
                    delete(LeftLine)
                end
                if isvalid(RightLine)
                    delete(RightLine)
                end
                LeftButton.Enable = 'on';
                RightButton.Enable = 'on';
                ResetBoundsButton.Enable = 'off';
        end
    end

    function ConfirmTraceDetails
        if isnan(Threshold) || isnan(LeftBound) || isnan(RightBound)
            ErrorCall.Text = 'Missing a boundary';
        else
            Average = mean(APVoltage(LeftBound:RightBound));
            close(DetailsFig)
        end
    end
end

function varargout = TracePolarity(Timescale, ControlStruct, MicrowaveStruct,ScreenSize)
    % Function that creates a toggleable graph to adjust AP polarity
    PromptFig = uifigure('Name', 'Selecting AP polarity', 'Position', [(ScreenSize(3)-650)/2 (ScreenSize(4)-600)/2 650 600]);
    Ax = uiaxes(PromptFig, 'Position', [25 90 600 500]);
    PolarityPlot = plot(Ax, Timescale, ControlStruct(1).APVals, 'Color', 'Red');
    title(Ax, 'Polarity Check: Voltage vs Time', 'FontSize', 16, 'FontWeight', 'Bold')
    xlabel(Ax, 'Time (s)', 'FontSize', 13)
    ylabel(Ax, 'Membrane Potential Difference (V)', 'FontSize', 13)
    xlim(Ax, [0 Timescale(end)])
    grid(Ax, 'on')

    Polarity = {1};
    uibutton(PromptFig, 'Push', 'Text', 'Toggle Polarity', 'Position', [245 60 150 30], 'ButtonPushedFcn', @(btn, event) TogglePolarity());
    uibutton(PromptFig, 'Push', 'Text', 'Confirm State', 'Position', [245 20 150 30], 'ButtonPushedFcn', @(btn, event) ConfirmPolarity(ControlStruct, MicrowaveStruct));
    uiwait(PromptFig)

    function TogglePolarity()
        Polarity{1} = -Polarity{1};
        if Polarity{1} == 1
            PolarityPlot.YData = ControlStruct(1).APVals;
        else
            PolarityPlot.YData = -ControlStruct(1).APVals;
        end
    end

    function ConfirmPolarity(ControlStruct,MicrowaveStruct)
        uiresume(PromptFig)
        close(PromptFig);
        parfor q = 1:length(ControlStruct)
            ControlStruct(q).APVals = Polarity{1} * ControlStruct(q).APVals; %#ok<PFBNS> 
        end
        parfor q = 1:length(MicrowaveStruct)
            MicrowaveStruct(q).APVals = Polarity{1} * MicrowaveStruct(q).APVals; %#ok<PFBNS> 
        end
        varargout{1} = ControlStruct;
        varargout{2} = MicrowaveStruct;
    end
end

function [FirstVal, LastVal, Length] = TraceSelect(ParametersStruct, ScreenSize,Range)
% Function that creates a selection UI for trace range and trace length
    FigPosition = [(ScreenSize(3)-1000)/2 (ScreenSize(4)-800)/2 1000 800];
    PromptFig = uifigure('Name', 'Trace Stability Analysis', 'Position', FigPosition);
    
    ax1 = uiaxes('Parent', PromptFig, 'Position', [50 470 450 300]);
    ax2 = uiaxes('Parent', PromptFig, 'Position', [500 470 450 300]);
    ax3 = uiaxes('Parent', PromptFig, 'Position', [50 160 450 300]);
    ax4 = uiaxes('Parent', PromptFig, 'Position', [500 160 450 300]);
    QuadStatsPlot(ParametersStruct, PromptFig, FigPosition, ax1, ax2, ax3, ax4);

    % Set the label, dropdown, and text box for FirstVal
    uilabel(PromptFig, 'Text', 'First (Default value is 1):', 'Position', [60 110 200 20], 'HorizontalAlignment', 'left');
    FirstValDropDown = uidropdown(PromptFig, 'Position', [220 110 100 20],'Items', {'Default', 'Other'}, 'Value', 'Default');
    FirstValTextBox = uitextarea(PromptFig, 'Position', [330 110 80 20], 'Visible', 'off');
    
    % Set the label, dropdown, and text box for LastVal
    uilabel(PromptFig, 'Text', sprintf('Last (Default value is %d):',Range), 'Position', [60 80 200 20], 'HorizontalAlignment', 'left');
    LastValDropDown = uidropdown(PromptFig, 'Position', [220 80 100 20],'Items', {'Default', 'Other'}, 'Value', 'Default');
    LastValTextBox = uitextarea(PromptFig, 'Position', [330 80 80 20], 'Visible', 'off');
    
    % Set the label, dropdown, and text box for Length
    uilabel(PromptFig, 'Text', 'Length of trace in seconds (Default value is 30):', 'Position', [60 50 300 20], 'HorizontalAlignment', 'left');
    LengthDropDown = uidropdown(PromptFig, 'Position', [330 50 100 20],'Items', {'Default', 'Other'}, 'Value', 'Default');
    LengthTextBox = uitextarea(PromptFig, 'Position', [440 50 80 20], 'Visible', 'off');
    
    % Error label
    ErrorLabel = uilabel(PromptFig, 'Text', '', 'Position', [60 30 340 20],'FontColor','red','Visible','off');
    uibutton(PromptFig, 'Position', [490 10 80 20], 'Text', 'Confirm', 'ButtonPushedFcn', @(btn,event) PressedConfirm());
    FirstValDropDown.ValueChangedFcn = @(dd,event) FirstDropdown();
    LastValDropDown.ValueChangedFcn = @(dd,event) LastDropdown();
    LengthDropDown.ValueChangedFcn = @(dd,event) LengthDropdown();
    uiwait(PromptFig);

    function PressedConfirm()
        if strcmp(FirstValDropDown.Value, 'Default')
            FirstVal = 1;
        else
            FirstVal = str2double(FirstValTextBox.Value);
        end
        if strcmp(LastValDropDown.Value, 'Default')
            LastVal = Range;
        else
            LastVal = str2double(LastValTextBox.Value);
        end
        if strcmp(LengthDropDown.Value, 'Default')
            Length = 30;
        else
            Length = str2double(LengthTextBox.Value);
        end
        if (FirstVal < 1)
            ErrorLabel.Text = sprintf('You must select a value greater than 1 for First');
            ErrorLabel.Visible = 'on';
            return;
        end
        if (FirstVal > Range || LastVal > Range)
            ErrorLabel.Text = sprintf('Your folder only has %d traces',Range);
            ErrorLabel.Visible = 'on';
            return;
        end
        if (FirstVal >= LastVal)
            ErrorLabel.Text = sprintf('Your Last value must be greater than your First value');
            ErrorLabel.Visible = 'on';
            return;
        end
        if (Length <= 0)
            ErrorLabel.Text = sprintf('Your trace length must be greater than 0 seconds');
            ErrorLabel.Visible = 'on';
            return;
        end
        if (strcmp(FirstValDropDown.Value, 'Other')&&isempty(cell2mat(FirstValTextBox.Value))|| ...
                strcmp(LastValDropDown.Value, 'Other')&&isempty(cell2mat(LastValTextBox.Value))|| ...
                strcmp(LengthDropDown.Value, 'Other')&&isempty(cell2mat(LengthTextBox.Value)))
            if strcmp(FirstValDropDown.Value, 'Other')&&isempty(cell2mat(FirstValTextBox.Value))
                ErrorLabel.Text = sprintf('The First field is blank');
            elseif strcmp(LastValDropDown.Value, 'Other')&&isempty(cell2mat(LastValTextBox.Value))
                ErrorLabel.Text = sprintf('The Last field is blank');
            else
                ErrorLabel.Text = sprintf('The Length field is blank');
            end
            ErrorLabel.Visible = 'on';
            return;
        end
        uiresume(PromptFig)
        close(PromptFig)
    end

    function FirstDropdown()
        if strcmp(FirstValDropDown.Value, 'Other')
            FirstValTextBox.Visible = 'on';
        else
            FirstValTextBox.Visible = 'off';
        end
    end

    function LastDropdown()
        if strcmp(LastValDropDown.Value, 'Other')
            LastValTextBox.Visible = 'on';
        else
            LastValTextBox.Visible = 'off';
        end
    end

    function LengthDropdown()
        if strcmp(LengthDropDown.Value, 'Other')
            LengthTextBox.Visible = 'on';
        else
            LengthTextBox.Visible = 'off';
        end
    end
end

function [StartIndex, EndIndex, NewTraceTime, NewTraceLength] = WindowAdjust(MicrowaveStruct, TraceTime, TraceLength, ScreenSize)
    % Create a uifigure to display example AP and options to select window
    PlotWidth = 600;
    PlotHeight = 400;
    Margin = 50;
    FigureWidth = PlotWidth + 2 * Margin;
    FigureHeight = PlotHeight + 150; % Extra space for controls
    PromptFig = uifigure('Name', 'Window Adjustment', 'Position', [ScreenSize(3)/4 ScreenSize(4)/4 FigureWidth FigureHeight]);
    Ax = uiaxes(PromptFig, 'Position', [Margin Margin+90 PlotWidth PlotHeight]);
    plot(Ax, TraceTime, MicrowaveStruct(1).APVals, 'Color', 'Red');
    title(Ax, 'Window Data', 'FontSize', 16, 'FontWeight', 'Bold');
    xlabel(Ax, 'Time (s)', 'FontSize', 13);
    ylabel(Ax, 'Membrane Potential Difference (V)', 'FontSize', 13);
    grid(Ax, 'on');

    % Create a dropdown for window selection
    WindowDropdown = uidropdown(PromptFig, 'Position', [Margin+35 110 120 20], 'Items', {'Default', 'Other'}, 'Value', 'Default', 'ValueChangedFcn', @(dd,event) UpdateVisibility());
    WindowStartLabel = uilabel(PromptFig, 'Position', [Margin+170 110 140 20], 'Text', 'Window Start Time:', 'Visible', 'off');
    WindowStartTextBox = uitextarea(PromptFig, 'Position', [Margin+290 110 100 20], 'Visible', 'off', 'ValueChangedFcn', @(tb,event) CheckInput());
    WindowEndLabel = uilabel(PromptFig, 'Position', [Margin+170 80 140 20], 'Text', 'Window End Time:', 'Visible', 'off');
    WindowEndTextBox = uitextarea(PromptFig, 'Position', [Margin+290 80 100 20], 'Visible', 'off', 'ValueChangedFcn', @(tb,event) CheckInput());
    ConfirmButton = uibutton(PromptFig, 'Push', 'Text', 'Confirm', 'Position', [PromptFig.Position(3)/2-40 15 80 30], 'ButtonPushedFcn', @(btn,event) ConfirmWindow(), 'Enable', 'on');
    ErrorLabel = uilabel(PromptFig, 'Position', [Margin+35 50 400 20], 'Text', '', 'FontColor', 'red', 'Visible', 'off');
    uiwait(PromptFig);
    
    function UpdateVisibility()
        if strcmp(WindowDropdown.Value, 'Other')
            WindowStartLabel.Visible = 'on';
            WindowStartTextBox.Visible = 'on';
            WindowEndLabel.Visible = 'on';
            WindowEndTextBox.Visible = 'on';
            ConfirmButton.Enable = 'off';
        else
            WindowStartLabel.Visible = 'off';
            WindowStartTextBox.Visible = 'off';
            WindowEndLabel.Visible = 'off';
            WindowEndTextBox.Visible = 'off';
            ConfirmButton.Enable = 'on';
        end
    end
    
    function CheckInput()
        if ~isempty(WindowStartTextBox.Value) && ~isempty(WindowEndTextBox.Value)
            ConfirmButton.Enable = 'on';
        else
            ConfirmButton.Enable = 'off';
        end
    end
    
    function ConfirmWindow()
        % Get the window selection from the user
        if strcmp(WindowDropdown.Value, 'Default')
            WindowStart = 0;
            WindowEnd = TraceLength;
        else
            % If the user selected "Other", extract the start and end times from the textbox
            WindowStart = str2double(WindowStartTextBox.Value);
            WindowEnd = str2double(WindowEndTextBox.Value);
        end
        if (WindowStart < 0)
            ErrorLabel.Text = sprintf('Window Start must be greater than 0');
            ErrorLabel.Visible = 'on';
            return;
        end
        if (WindowStart > TraceLength || WindowEnd > TraceLength)
            ErrorLabel.Text = sprintf('Trace is %d seconds long',TraceLength);
            ErrorLabel.Visible = 'on';
            return;
        end
        if (WindowStart >= WindowEnd)
            ErrorLabel.Text = sprintf('Window End must be greater than Window Start');
            ErrorLabel.Visible = 'on';
            return;
        end
        if (strcmp(WindowDropdown.Value, 'Other')&&isempty(WindowStartTextBox.Value)||strcmp(WindowDropdown.Value, 'Other')&&isempty(WindowEndTextBox.Value))
            if strcmp(WindowDropdown.Value, 'Other')&&isempty(WindowStartTextBox.Value)
                ErrorLabel.Text = sprintf('Window Start Time is blank');
            else
                ErrorLabel.Text = sprintf('Window End Time is blank');
            end
            ErrorLabel.Visible = 'on';
            return;
        end

        % Convert the window times to indices
        StartIndex = Sec2Index(WindowStart, TraceTime, TraceLength);
        EndIndex = Sec2Index(WindowEnd, TraceTime, TraceLength);

        % Correct the trace length and generate a new TraceTime vector
        if (strcmp(WindowDropdown.Value, 'Default') || (WindowEnd - WindowStart) == TraceLength)
            NewTraceLength = TraceLength;
        else
            NewTraceLength = WindowEnd - WindowStart;
        end
        close(PromptFig);
        NewTraceTime = linspace(WindowStart, WindowEnd, numel(MicrowaveStruct(1).APVals(StartIndex:EndIndex)));
    end
end

%% Conversions & Colors Functions
function ColorTriplet = AxonColor(Axon)
    if isnan(Axon)
        ColorTriplet = [0 0 1];
    else
        Colors = {[0 0.7 0], [1 0.3 0], [0.85 0 0.85], [0.6 0 0], [0 0.7 0.65], [0.85 0.6 0]};
        ColorTriplet = Colors{Axon};
    end
end

function ColorTriplet = AxonColorM(Axon)
    if isnan(Axon)
        ColorTriplet = [0 0 1];
    else
        Colors = {[0 0.54 0], [0.82 0.3 0], [0.73 0 0.73], [0.44 0 0], [0 0.61 0.53], [0.75 0.53 0]};
        ColorTriplet = Colors{Axon};
    end
end

function Seconds = Index2Sec(Index,TimeAxis,TimeLength)
    if Index == length(TimeAxis)
        Seconds = TimeLength;
    else
        Seconds = (Index-1)*(TimeLength/length(TimeAxis));
    end
end

function Index = Sec2Index(Seconds,TimeAxis,TimeLength)
    if Seconds == TimeLength
        Index = length(TimeAxis);
    else
        Index = round(Seconds/(TimeLength/length(TimeAxis))) + 1;
    end
end

function TData = Trimmer(TData,LowerPercentile,UpperPercentile)
% Function to winsorize data at given percentiles
    UpperFence = prctile(TData,UpperPercentile);
    LowerFence = prctile(TData,LowerPercentile);
    TData(TData>UpperFence) = [];
    TData(TData<LowerFence) = [];
end

function WData = Winsorize(WData,LowerPercentile,UpperPercentile)
% Function to winsorize data at given percentiles
    UpperFence = prctile(WData,UpperPercentile);
    LowerFence = prctile(WData,LowerPercentile);
    WData(WData>UpperFence) = UpperFence;
    WData(WData<LowerFence) = LowerFence;
end

%% Spike Sorting & Labeling Functions
function DataStruct = SpikeSort(DataStruct, WindowStart, WindowEnd, TraceTime, TraceLength, Threshold, Average)
% Funtion that detects the characteristics of action potentials
    % Setting spike detection ranges;
    TimeBetweenCross = 0.003;
    OnsetSearchRange = 0.0025;
    PeakSearchRange = 0.002;
    PostPeakSearchRange = 0.003;
    IncreasedCatchRange = 0.001;
    RecededPostPeakSearchRange = 0.001;
    EdgeEliminationRange = 0.01;
    
    % Converting values to set up parfor loop
    TimeBetweenCross = Sec2Index(TimeBetweenCross,TraceTime,TraceLength);
    OnsetSearchRange = Sec2Index(OnsetSearchRange,TraceTime,TraceLength);
    PeakSearchRange = Sec2Index(PeakSearchRange,TraceTime,TraceLength);
    PostPeakSearchRange = Sec2Index(PostPeakSearchRange,TraceTime,TraceLength);
    IncreasedCatchRange = Sec2Index(IncreasedCatchRange,TraceTime,TraceLength);
    RecededPostPeakSearchRange = Sec2Index(RecededPostPeakSearchRange,TraceTime,TraceLength);
    EdgeEliminationRange = Sec2Index(EdgeEliminationRange,TraceTime,TraceLength);

    % Pre-allocate fields to be added
    TraceCount = length(DataStruct);
    for f = 1:TraceCount
        DataStruct(f).APOnsets = {};
        DataStruct(f).APPeaks = {};
        DataStruct(f).APAHPs = {};
        DataStruct(f).APAmplitudes = [];
        DataStruct(f).APAHPAmplitudes = [];
        DataStruct(f).APDurations = [];
    end

    % Creating loading bar
    F(TraceCount) = parallel.FevalFuture;
    if (mod(DataStruct(1).Trace,2) == 1)
        Identifier = 'control';
    else
        Identifier = 'microwave';
    end
    LoadingBar = waitbar(0, sprintf('Preparing parallel %s spike sort...',Identifier));


    % Individual traces delegated to workers
    for g = 1:TraceCount
        F(g) = parfeval(gcp("nocreate"),@SingleTraceSort,1,DataStruct(g),WindowStart,WindowEnd,TraceTime,TraceLength,Threshold,Average,TimeBetweenCross,OnsetSearchRange,PeakSearchRange,PostPeakSearchRange,IncreasedCatchRange,RecededPostPeakSearchRange,EdgeEliminationRange);
    end

    for Idc = 1:TraceCount
        [CompletedIdx, Resultant] = fetchNext(F);
        DataStruct(CompletedIdx) = Resultant;
        waitbar(CompletedIdx/TraceCount,LoadingBar, sprintf('Sorting %s spikes: %d remaining', Identifier, TraceCount-CompletedIdx));
    end
    close(LoadingBar)
end

function Data = SingleTraceSort(Data, WindowStart, WindowEnd, TraceTime, TraceLength, Threshold, Average, TimeBetweenCross, OnsetSearchRange, PeakSearchRange, PostPeakSearchRange, IncreasedCatchRange, RecededPostPeakSearchRange,EdgeEliminationRange)
    CrossDetected = false;
    IndexSpacing = TimeBetweenCross;
    SpikeCounter = 0;
    for k = WindowStart:WindowEnd-1
        Current = Data.APVals(k);
        if ~CrossDetected && Current < Threshold && IndexSpacing >= TimeBetweenCross && k < WindowEnd-EdgeEliminationRange 
            SpikeCounter = SpikeCounter + 1;

            %Pre-peak maximum
            OnsetSearch = min(OnsetSearchRange,length(Data.APVals(WindowStart:k))-1);
            [OnsetVal, OnsetIndexTemp] = max(Data.APVals(k-OnsetSearch:k));
            OnsetIndex = OnsetIndexTemp + k-OnsetSearch;
            if SpikeCounter > 1 && (Data.APAHPs{SpikeCounter-1}(2) == OnsetIndex || Data.APAHPs{SpikeCounter-1}(1) == OnsetVal) %Peak Overlap Detection
                SpikeCounter = SpikeCounter - 1;
            end
            Data.APOnsets{SpikeCounter} = [OnsetVal, OnsetIndex];

            %Peak
            PeakSearch = min(PeakSearchRange,WindowEnd-k);
            [PeakVal, PeakIndexTemp] = min(Data.APVals(k:k+PeakSearch));
            PeakIndex = PeakIndexTemp + k;
            Data.APPeaks{SpikeCounter} = [PeakVal, PeakIndex];

            %Post-peak maximum
            PostPeakSearch = min(PostPeakSearchRange,WindowEnd-k);
            [PostPeakVal, PostPeakIndexTemp] = max(Data.APVals(k:k+PostPeakSearch));
            PostPeakIndex = PostPeakIndexTemp + k;
            IncreasedSearch = min(IncreasedCatchRange,WindowEnd-PostPeakIndex);
            if any(Data.APVals(PostPeakIndex:PostPeakIndex+IncreasedSearch) < Threshold)
                PostPeakSearch = min(RecededPostPeakSearchRange,WindowEnd-k);
                [PostPeakVal, PostPeakIndexTemp] = max(Data.APVals(k:k+PostPeakSearch));
                PostPeakIndex = PostPeakIndexTemp + k;
            end
            Data.APAHPs{SpikeCounter} = [PostPeakVal, PostPeakIndex];

            %Calculated
            Data.APAmplitudes(SpikeCounter) = OnsetVal-PeakVal;
            Data.APAHPAmplitudes(SpikeCounter) = PostPeakVal-Average;
            Data.APDurations(SpikeCounter) = Index2Sec(PostPeakIndex,TraceTime,TraceLength) - Index2Sec(OnsetIndex,TraceTime,TraceLength);
            CrossDetected = true;
            IndexSpacing = 0;
        else
            CrossDetected = false;
            IndexSpacing = IndexSpacing + 1;
        end
    end
end

function varargout = TraceBounds(DataStruct,ScreenSize)
    % Initial configuration
    FigPosition = [(ScreenSize(3)-1200)/2 (ScreenSize(4)-800)/2 1200 800];
    if (mod(DataStruct(1).Trace,2) == 1)
        Identifier = 'Control';
    else
        Identifier = 'Microwave';
    end
    PromptFig = uifigure('Name', sprintf('%s Raster Plot',Identifier), 'Position', FigPosition);
    ax = uiaxes(PromptFig, 'Position', [25 100 1000 700]);
    title(ax,sprintf('%s Raster Plot',Identifier),'FontSize',16,'FontWeight','Bold')

    % Raster plotting
    RunningAmpCount = 1;
    for n = 1:length(DataStruct)
        AmpVals = DataStruct(n).APAmplitudes;
        AmpCount = length(AmpVals);
        XReference = RunningAmpCount:RunningAmpCount+AmpCount-1;
        yyaxis(ax,'left')
        scatter(ax,XReference,AmpVals,10,'filled')
        hold(ax,'on')
        yyaxis(ax,'right')
        Y = repmat(DataStruct(n).Trace,size(XReference));
        line(ax,XReference,Y,'Color',[0.7 0.7 0.7],'LineWidth',3)
        hold(ax,'on')
        RunningAmpCount = RunningAmpCount + AmpCount;
    end
    xlabel(ax,'Peak Number')
    xlim(ax,'tight')
    yyaxis(ax,'left')
    ylabel(ax,'Amplitude Voltage (V)')
    ax.YAxis(1).Color = 'k';
    yyaxis(ax,'right')
    ax.YAxis(2).Color = 'k';
    ylabel(ax,'Trace (#)')
    grid(ax,'on')

    % UI elements
    MaxAPNum = 6;
    ButtonSets = cell(MaxAPNum, 1);
    XSpacing = 25;
    for n = 1:MaxAPNum
        ButtonSets{n}.Label = uilabel(PromptFig, 'Position', [XSpacing+50 70 150 20], 'Text', sprintf('Axon %d:', n), 'Visible', 'off','FontColor',AxonColor(n),'FontWeight','Bold');
        ButtonSets{n}.UBtn = uibutton(PromptFig, 'Position', [XSpacing 50 150 20], 'Text', 'Set Upper Bound', 'ButtonPushedFcn', @(btn,event) SetBound(btn,event,n,'Upper'), 'Visible', 'off');
        ButtonSets{n}.LBtn = uibutton(PromptFig, 'Position', [XSpacing 30 150 20], 'Text', 'Set Lower Bound', 'ButtonPushedFcn', @(btn,event) SetBound(btn,event,n,'Lower'), 'Visible', 'off');
        ButtonSets{n}.RBtn = uibutton(PromptFig, 'Position', [XSpacing 10 150 20], 'Text', 'Reset', 'ButtonPushedFcn', @(btn,event) ResetBound(btn,event,n), 'Visible', 'off');
        ButtonSets{n}.ULine = [];
        ButtonSets{n}.LLine = [];
        ButtonSets{n}.Highlight = [];
        XSpacing = XSpacing + 200;
    end

    yZoomBounds = [NaN NaN];
    YZoomLabel = uilabel(PromptFig, 'Position', [1030 650 150 20], 'Text', 'Define Y Range:', 'FontWeight', 'bold','Visible','off');
    SetUpperYZoomBtn = uibutton(PromptFig, 'Position', [1030 630 150 20], 'Text', 'Set Upper Y Zoom', 'ButtonPushedFcn', @(btn,event) SetYZoom(btn,ax,1),'Visible','off');
    SetLowerYZoomBtn = uibutton(PromptFig, 'Position', [1030 610 150 20], 'Text', 'Set Lower Y Zoom', 'ButtonPushedFcn', @(btn,event) SetYZoom(btn,ax,2),'Visible','off');
    ResetYZoomBtn = uibutton(PromptFig, 'Position', [1030 590 150 20], 'Text', 'Reset Y Zoom', 'ButtonPushedFcn', @(btn,event) ResetYZoom(btn,ax,SetUpperYZoomBtn,SetLowerYZoomBtn),'Visible','off');
    TraceZoomLabel = uilabel(PromptFig,'Position',[1030 560 150 20],'Text','Define Trace Window:','FontWeight','bold','Visible','off');
    FirstTraceNum = uidropdown(PromptFig,'Position',[1030 540 150 20],'Items',cellfun(@num2str, {DataStruct(:).Trace}, 'UniformOutput', false),'Visible','off');
    LastTraceNum = uidropdown(PromptFig,'Position',[1030 520 150 20],'Items',cellfun(@num2str, {DataStruct(:).Trace}, 'UniformOutput', false),'Visible','off');
    ConfirmTraceZoomBtn = uibutton(PromptFig,'Position',[1030 500 150 20],'Text','Set Trace Window','ButtonPushedFcn',@(btn,event)ConfirmXZoom(btn,ax,FirstTraceNum.Value,LastTraceNum.Value),'Visible','off');
    ResetTraceZoomBtn = uibutton(PromptFig,'Position',[1030 480 150 20],'Text','Reset Trace Zoom','ButtonPushedFcn',@(btn,event)ResetXZoom(btn,ax,ConfirmTraceZoomBtn),'Visible','off');

    uilabel(PromptFig, 'Position', [1030 700 150 20], 'Text', 'Select number of axons:','FontWeight','Bold');
    AxonNum = uidropdown(PromptFig, 'Position', [1030 680 50 20], 'Items', arrayfun(@(x)num2str(x),1:MaxAPNum,'UniformOutput',false));
    uibutton(PromptFig, 'Position', [1080 680 100 20], 'Text', 'Confirm', 'ButtonPushedFcn', @(btn,event) AxonButtonSets(ButtonSets,AxonNum.Value,MaxAPNum,YZoomLabel,SetUpperYZoomBtn,SetLowerYZoomBtn,ResetYZoomBtn));
    ConfirmBoundsBtn = uibutton(PromptFig,'Position',[1030 420 150 30],'Text','Confirm Axon Bounds','FontSize',13,'FontWeight','Bold','ButtonPushedFcn',@(btn,event) ConfirmBounds(),'Visible','off');
    ConfirmError = uilabel(PromptFig,'Position',[1030 395 175 20],'Text','','FontColor','Red','FontWeight','Bold');
    waitfor(ConfirmError, 'Text', 'Done')
    
    function AxonButtonSets(ButtonSets,AxonNum,MaxAPNum,YZoomLabel,SetUpperYZoomBtn,SetLowerYZoomBtn,ResetYZoomBtn)
        for k = 1:MaxAPNum
            ButtonSets{k}.Label.Visible = 'off';
            ButtonSets{k}.UBtn.Visible = 'off';
            ButtonSets{k}.LBtn.Visible = 'off';
            ButtonSets{k}.RBtn.Visible = 'off';
        end
        for k = 1:str2double(AxonNum)
            ButtonSets{k}.Label.Visible = 'on';
            ButtonSets{k}.UBtn.Visible = 'on';
            ButtonSets{k}.LBtn.Visible = 'on';
            ButtonSets{k}.RBtn.Visible = 'on';
        end
        YZoomLabel.Visible = 'on';
        SetUpperYZoomBtn.Visible = 'on';
        SetLowerYZoomBtn.Visible = 'on';
        ResetYZoomBtn.Visible = 'on';
        TraceZoomLabel.Visible = 'on';
        FirstTraceNum.Visible = 'on';
        LastTraceNum.Visible = 'on';
        ConfirmTraceZoomBtn.Visible = 'on';
        ResetTraceZoomBtn.Visible = 'on';
        ConfirmBoundsBtn.Visible = 'on';
    end

    function SetBound(src,~,Axon,Label)
        src.Enable = 'off';
        OriginalText = src.Text;
        T = timer('TimerFcn',{@UpdateText, src},'Period',1,'ExecutionMode','FixedRate');
        start(T)
        yyaxis(ax, 'left')
        PLine = drawpolyline(ax,'Color',[0.5 0 0.5]);
        Pos = PLine.Position;
        delete(PLine);
        XLimits = xlim(ax);
        [~, UnX] = unique(Pos(:,1), 'stable');
        Pos = Pos(UnX,:);
        Pos = [[XLimits(1), Pos(1,2)]; Pos; [XLimits(2), Pos(end,2)]];
        if strcmp(Label,'Upper')
            ButtonSets{Axon}.ULine = line(ax, Pos(:,1), Pos(:,2), 'Color', AxonColor(Axon));
        elseif strcmp(Label,'Lower')
            ButtonSets{Axon}.LLine = line(ax, Pos(:,1), Pos(:,2), 'Color', AxonColor(Axon));
        end
        if ~isempty(ButtonSets{Axon}.ULine) && ~isempty(ButtonSets{Axon}.LLine)
            X = [ButtonSets{Axon}.ULine.XData, fliplr(ButtonSets{Axon}.LLine.XData)];
            Y = [ButtonSets{Axon}.ULine.YData, fliplr(ButtonSets{Axon}.LLine.YData)];
            ButtonSets{Axon}.Highlight = patch(X,Y,AxonColor(Axon),'Parent',ax,'FaceAlpha',0.5,'EdgeColor','none');
        end
        stop(T);
        delete(T);
        src.Text = OriginalText;
    end

    function UpdateText(~,~,btn)
        CurrentText = btn.Text;
        if strcmp(CurrentText, 'Selecting')
            NextText = 'Selecting.';
        elseif strcmp(CurrentText, 'Selecting.')
            NextText = 'Selecting..';
        elseif strcmp(CurrentText, 'Selecting..')
            NextText = 'Selecting...';
        else
            NextText = 'Selecting';
        end
        btn.Text = NextText;
    end

        function ResetBound(src,~,Axon)
            src.Enable = 'on';
            ButtonSets{Axon}.UBtn.Enable = 'on';
            ButtonSets{Axon}.LBtn.Enable = 'on';
            if ~isempty(ButtonSets{Axon}.ULine)
                delete(ButtonSets{Axon}.ULine);
                ButtonSets{Axon}.ULine = [];
            end
            if ~isempty(ButtonSets{Axon}.LLine)
                delete(ButtonSets{Axon}.LLine);
                ButtonSets{Axon}.LLine = [];
            end
            if ~isempty(ButtonSets{Axon}.Highlight)
                delete(ButtonSets{Axon}.Highlight);
                ButtonSets{Axon}.Highlight = [];
            end
        end

    function SetYZoom(btn,ax,Index)
        btn.Enable = 'off';
        OriginalText = btn.Text;
        T = timer('TimerFcn',{@UpdateText, btn},'Period',1,'ExecutionMode','FixedRate');
        start(T)
        ax.ButtonDownFcn = @(ax,event) CaptureClick(ax,event,btn,OriginalText,Index,T,ResetYZoomBtn);
    end

    function ResetYZoom(btn,ax,SetUpperYZoomBtn,SetLowerYZoomBtn)
        ylim(ax,'auto');
        btn.Enable = 'off';
        SetUpperYZoomBtn.Enable = 'on';
        SetLowerYZoomBtn.Enable = 'on';
        yZoomBounds = [NaN NaN];
    end

    function CaptureClick(ax,event,btn,OriginalText,Index,T,ResetYZoomBtn)
        Coordinates = event.IntersectionPoint;
        yZoomBounds(Index) = Coordinates(2);
        stop(T)
        delete(T);
        btn.Text = OriginalText;
        ax.ButtonDownFcn = '';
        if all(~isnan(yZoomBounds))
            yyaxis(ax, 'left');
            ylim(ax,[min(yZoomBounds) max(yZoomBounds)]);
            ResetYZoomBtn.Enable = 'on';
        end
    end

    function ConfirmXZoom(btn, ax, FirstTrace, LastTrace)
        FirstTrace = str2double(FirstTrace);
        LastTrace = str2double(LastTrace);
        FirstTraceStart = find([DataStruct.Trace] == FirstTrace, 1, 'first');
        LastTraceEnd = find([DataStruct.Trace] == LastTrace, 1, 'last');
        if ~isempty(FirstTraceStart) && ~isempty(LastTraceEnd)
            FirstTraceStart = sum(arrayfun(@(x) length(x.APAmplitudes), DataStruct(1:FirstTraceStart-1))) + 1;
            LastTraceEnd = sum(arrayfun(@(x) length(x.APAmplitudes), DataStruct(1:LastTraceEnd)));
            yl = ylim(ax);
            xlim(ax, [FirstTraceStart, LastTraceEnd]);
            ylim(ax,yl);
            btn.Enable = 'off';
            ResetTraceZoomBtn.Enable = 'on';
        end
    end

    function ResetXZoom(btn, ax, ConfirmTraceZoomBtn)
        xlim(ax, 'auto');
        btn.Enable = 'off';
        ConfirmTraceZoomBtn.Enable = 'on';
    end

    function ConfirmBounds()
        AxonCheck = str2double(AxonNum.Value);
        for k = 1:AxonCheck
            if isempty(ButtonSets{k}.ULine) || isempty(ButtonSets{k}.LLine)
                ConfirmError.Text = sprintf('Axon %d bounds missing',k);
                ConfirmError.Visible = 'on';
                return
            end
            ConfirmError.Visible = 'off';
        end

        RunningAmpCount = 1;
        for q = 1:length(DataStruct)
            AmpVals = DataStruct(q).APAmplitudes;
            AmpCount = length(AmpVals);
            DataStruct(q).AxonLabels = zeros(AmpCount,1);
            XStart = RunningAmpCount;
            XEnd = RunningAmpCount + AmpCount -1;
            for k = 1:AxonCheck
                DataStruct(q).AxonLabels(inpolygon(XStart:XEnd,DataStruct(q).APAmplitudes,ButtonSets{k}.Highlight.XData,ButtonSets{k}.Highlight.YData)) = k;
            end
            DataStruct(q).AxonLabels(DataStruct(q).AxonLabels == 0) = NaN;
            RunningAmpCount = RunningAmpCount + AmpCount;
        end
        varargout{1} = DataStruct;
        ConfirmError.Text = 'Done';
        close(PromptFig)
    end
end

function varargout = SecondTraceBounds(DataStruct,ScreenSize)
    % Initial configuration
    FigPosition = [(ScreenSize(3)-1200)/2 (ScreenSize(4)-800)/2 1200 800];
    if (mod(DataStruct(1).Trace,2) == 1)
        Identifier = 'Control';
    else
        Identifier = 'Microwave';
    end
    PromptFig = uifigure('Name', sprintf('%s Raster Plot',Identifier), 'Position', FigPosition);
    ax = uiaxes(PromptFig, 'Position', [25 100 1000 700]);
    title(ax,sprintf('%s Extremas Cluster Plot',Identifier),'FontSize',16,'FontWeight','Bold')
    
    % Calculate total number of elements
    numElements = sum(arrayfun(@(x) length(x.APAmplitudes), DataStruct));
    
    % Preallocate memory
    AmpValues = zeros(1, numElements);
    OnsetValues = zeros(1, numElements);
    AxonColoring = zeros(numElements, 1);
    
    % Cluster Plot
    count = 0;
    for q = 1:length(DataStruct)
        numInnerElements = length(DataStruct(q).APAmplitudes);
        AmpValues(count+1:count+numInnerElements) = cellfun(@(x) x(1), DataStruct(q).APOnsets(1:numInnerElements));
        OnsetValues(count+1:count+numInnerElements) = cellfun(@(x) x(1), DataStruct(q).APPeaks(1:numInnerElements));
        AxonColoring(count+1:count+numInnerElements) = DataStruct(q).AxonLabels(1:numInnerElements);
        count = count + numInnerElements;
    end
    AxonColors = arrayfun(@AxonColor, AxonColoring, 'UniformOutput', false);
    AxonColors = reshape(cell2mat(AxonColors), [], 3);

    scatter(ax,AmpValues,OnsetValues,10,AxonColors,'filled');
    xlabel(ax,'Minimum (Negative Peak)')
    ylabel(ax,'Maximum (Onset Peak)')
    grid (ax,'on')
    
    % Ui elements
    MaxAPNum = 6;
    XSpacing = 25;
    ButtonSets = cell(1,MaxAPNum);
    for n = 1:MaxAPNum
        ButtonSets{n}.Label = uilabel(PromptFig, 'Position', [XSpacing+50 70 150 20], 'Text', sprintf('Axon %d:', n), 'Visible', 'off','FontColor',AxonColor(n),'FontWeight','Bold');
        ButtonSets{n}.CBtn = uibutton(PromptFig, 'Position', [XSpacing 50 150 20], 'Text', 'Set Cluster Bound', 'ButtonPushedFcn', @(btn,event) SetBound(btn,event,n), 'Visible', 'off');
        ButtonSets{n}.RBtn = uibutton(PromptFig, 'Position', [XSpacing 30 150 20], 'Text', 'Reset', 'ButtonPushedFcn', @(btn,event) ResetBound(btn,event,n), 'Visible', 'off');
        ButtonSets{n}.Line = [];
        ButtonSets{n}.Highlight = [];
        XSpacing = XSpacing + 200;
    end
    uilabel(PromptFig, 'Position', [1030 700 150 20], 'Text', 'Select number of axons:','FontWeight','Bold');
    AxonNum = uidropdown(PromptFig, 'Position', [1030 680 50 20], 'Items', arrayfun(@(x)num2str(x),1:MaxAPNum,'UniformOutput',false));
    uibutton(PromptFig, 'Position', [1080 680 100 20], 'Text', 'Confirm', 'ButtonPushedFcn', @(btn,event) AxonButtonSets(ButtonSets,AxonNum.Value,MaxAPNum));
    ConfirmBoundsBtn = uibutton(PromptFig,'Position',[1030 420 150 30],'Text','Confirm Axon Bounds','FontSize',13,'FontWeight','Bold','ButtonPushedFcn',@(btn,event) ConfirmBounds(),'Visible','off');
    ConfirmError = uilabel(PromptFig,'Position',[1030 395 175 20],'Text','','FontColor','Red','FontWeight','Bold');
    waitfor(ConfirmError, 'Text', 'Done')

    function AxonButtonSets(ButtonSets,AxonNum,MaxAPNum)
        for f = 1:MaxAPNum
            ButtonSets{f}.Label.Visible = 'off';
            ButtonSets{f}.CBtn.Visible = 'off';
            ButtonSets{f}.RBtn.Visible = 'off';
        end
        for f = 1:str2double(AxonNum)
            ButtonSets{f}.Label.Visible = 'on';
            ButtonSets{f}.CBtn.Visible = 'on';
            ButtonSets{f}.RBtn.Visible = 'on';
            ConfirmBoundsBtn.Visible = 'on';
        end
    end

    function SetBound(src,~,AxonLabel)
        src.Enable = 'off';
        OriginalText = src.Text;
        T = timer('TimerFcn',{@UpdateText, src},'Period',1,'ExecutionMode','FixedRate');
        start(T)
        PLine = drawpolygon(ax,'Color',[0.5 0 0.5]);
        Pos = PLine.Position;
        delete(PLine);
        ButtonSets{AxonLabel}.Line = line(ax,Pos(:,1),Pos(:,2),'Color',AxonColor(AxonLabel));
        X = ButtonSets{AxonLabel}.Line.XData;
        Y = ButtonSets{AxonLabel}.Line.YData;
        ButtonSets{AxonLabel}.Highlight = patch(X,Y,AxonColor(AxonLabel),'Parent',ax,'FaceAlpha',0.5,'EdgeColor','none');
        stop(T);
        delete(T);
        src.Text = OriginalText;
    end

    function UpdateText(~,~,btn)
        CurrentText = btn.Text;
        if strcmp(CurrentText, 'Selecting')
            NextText = 'Selecting.';
        elseif strcmp(CurrentText, 'Selecting.')
            NextText = 'Selecting..';
        elseif strcmp(CurrentText, 'Selecting..')
            NextText = 'Selecting...';
        else
            NextText = 'Selecting';
        end
        btn.Text = NextText;
    end

    function ResetBound(src,~,Axon)
        src.Enable = 'on';
        ButtonSets{Axon}.CBtn.Enable = 'on';
        delete(ButtonSets{Axon}.Line);
        ButtonSets{Axon}.Line = [];
        delete(ButtonSets{Axon}.Highlight);
        ButtonSets{Axon}.Highlight = [];
    end

    function ConfirmBounds()
        % Check for all bounds
        AxonCheck = str2double(AxonNum.Value);
        for z = 1:AxonCheck
            if isempty(ButtonSets{z}.Line)
                ConfirmError.Text = sprintf('Axon %d bound is missing',z);
                ConfirmError.Visible = 'on';
                return
            end
            ConfirmError.Visible = 'off';
        end
        % Update labeling
        RunningAmpCount = 1;
        for z = 1:length(DataStruct)
            AmpVals = DataStruct(z).APAmplitudes;
            AmpCount = length(AmpVals);
            DataStruct(z).AxonLabels = zeros(AmpCount,1);
            XStart = RunningAmpCount;
            XEnd = RunningAmpCount + AmpCount -1;
            for k = 1:AxonCheck
                DataStruct(z).AxonLabels(inpolygon(XStart:XEnd,DataStruct(z).APAmplitudes,ButtonSets{k}.Highlight.XData,ButtonSets{k}.Highlight.YData)) = k;
            end
            DataStruct(z).AxonLabels(DataStruct(z).AxonLabels == 0) = NaN;
            RunningAmpCount = RunningAmpCount + AmpCount;
        end
        varargout{1} = DataStruct;
        ConfirmError.Text = 'Done';
        close(PromptFig)
    end
end

%% Figure Generation Functions
function AlignedAPs = AlignAPs(APVals,PaddingVal)
% Function that aligns all APs in a matrix by their peak
    AlignedAPs = [];
    for v = 1:length(APVals)
        if isempty(AlignedAPs)
            AlignedAPs = APVals{v};
        else
            [~,TempIndex] = min(AlignedAPs,[],2);
            AlignedPeakIndex = unique(TempIndex);
            PeakIndex = find(APVals{v} == min(APVals{v}),1);
            Offset = AlignedPeakIndex-PeakIndex;
            PaddedAP = APVals{v};
            if Offset > 0
                PaddedAP = [PaddingVal*ones(1,Offset),PaddedAP]; %#ok<AGROW>
            elseif Offset < 0
                AlignedAPs = [PaddingVal*ones(height(AlignedAPs),abs(Offset)),AlignedAPs]; %#ok<AGROW>
            end
            Offset = width(AlignedAPs)-length(PaddedAP);
            if Offset > 0
                PaddedAP = [PaddedAP,PaddingVal*ones(1,Offset)]; %#ok<AGROW>
            elseif Offset < 0
                AlignedAPs = [AlignedAPs,PaddingVal*ones(height(AlignedAPs),abs(Offset))]; %#ok<AGROW>
            end
            AlignedAPs = [AlignedAPs;PaddedAP]; %#ok<AGROW>
        end
    end
end

function APComparePlot(ScreenSize,ControlStruct,MicrowaveStruct,PaddingVal,TraceTime,TraceLength)
% Function to create AP comparison plot
    APCompFig = figure('Name','AP Compariso Plots','Position',[(ScreenSize(3)-1600)/2 (ScreenSize(4)-600)/2 1600 600]);
    MaxAxons = max(arrayfun(@(x) max(x.AxonLabels), ControlStruct));
    TLayout = tiledlayout(APCompFig,1,MaxAxons);
    for q = 1:MaxAxons
        % Creates onset-aligned average AP
        nexttile(TLayout);       
        hold on
        APPair = {};
        APPair{1} = GetAvgAP(ControlStruct,q,PaddingVal,TraceTime,TraceLength);
        APPair{2} = GetAvgAP(MicrowaveStruct,q,PaddingVal,TraceTime,TraceLength);
        AlignedPair = AlignAPs(APPair,PaddingVal);
        plot(AlignedPair(1,:),'Color',[AxonColor(q), 0.6],'LineWidth',3)
        plot(AlignedPair(2,:),'Color',[[1 1 1]-AxonColor(q), 0.6],'LineWidth',3)

        % Creates comparison points
        Points(:,:,1) = FindKeyComparePoints(AlignedPair(1,:));
        Points(:,:,2) = FindKeyComparePoints(AlignedPair(2,:));
        MidPoints = mean(Points,3);
        Differences = Points(:,:,2)-Points(:,:,1);
        PeakTexts = ["Onset Difference","Peak Difference","AHP Difference"];
        for k = 1:3
            line([MidPoints(k,1), MidPoints(k,1)+MidPoints(k,1)/6],repmat(MidPoints(k,2),[1,2]),'Color',[0 0 0 0.65],'LineWidth',1,'HandleVisibility','off')
            DiffExpression = sprintf('%s:\n%0.3e V',PeakTexts(k),Differences(k,2));
            DiffExpression = regexprep(DiffExpression, 'e\+?0*(\d+)', ' x 10^$1');
            text(MidPoints(k,1)+MidPoints(k,1)/5.95,MidPoints(k,2),regexprep(DiffExpression, 'e-(0*)(\d+)', ' x 10^-$2'),'Color',[0 0 0 0.65]);
        end
        title(sprintf('Axon %d',q),'FontSize',12)
        set(gca,'xtick',[],'xticklabel',[])
        %set(gca,'ytick',[],'yticklabel',[])
    end
    ylabel(TLayout,'Voltage (V)')
    title(TLayout,'Average APs per Axon','FontSize',14,'FontWeight','Bold')
    axis padded
    LegendPlots = gobjects(MaxAxons*2,1);
    for n = 1:MaxAxons
        LegendPlots(n) = plot(gca,NaN,NaN,'LineStyle','none','Marker','.','MarkerSize',20,'Color',AxonColor(n));
        LegendPlots(n+MaxAxons) = plot(gca,NaN,NaN,'LineStyle','none','Marker','.','MarkerSize',20,'Color',[1 1 1]-AxonColor(n));
    end
    %ControlEntries = arrayfun(@(x)['Control Axon ', num2str(x)],1:MaxAxons,'UniformOutput',false);
    %MicrowaveEntries = arrayfun(@(x)['Microwave Axon ', num2str(x)],1:MaxAxons,'UniformOutput',false);
    LegendPlots = gobjects(MaxAxons*2,1);
    LegendEntries = cell(1, MaxAxons*2);
    for n = 1:MaxAxons
        LegendPlots(n*2-1) = plot(gca,NaN,NaN,'LineStyle','none','Marker','.','MarkerSize',20,'Color',AxonColor(n));
        LegendEntries{n*2-1} = ['Control Axon ', num2str(n)];
        
        LegendPlots(n*2) = plot(gca,NaN,NaN,'LineStyle','none','Marker','.','MarkerSize',20,'Color',[1 1 1]-AxonColor(n));
        LegendEntries{n*2} = ['Microwave Axon ', num2str(n)];
    end
    LegendT = legend(gca,LegendPlots,LegendEntries,'NumColumns',MaxAxons,'FontSize',12);
    LegendT.Layout.Tile = 'South';
    fontname(APCompFig,'Century Schoolbook')
    
    function Points = FindKeyComparePoints(APVec)
    % Function to find onset, peak, and AHP indices of an AP vector for plots
        [PeakVal,PeakIndex] = min(APVec);
        [OnsetVal,OnsetIndex] = max(APVec(1:PeakIndex));
        [AHPVal,AHPIndex] = max(APVec(PeakIndex:end));
        AHPIndex = AHPIndex + PeakIndex;
        Points = [OnsetIndex,OnsetVal;PeakIndex,PeakVal;AHPIndex,AHPVal];
    end
end

function AvgAP = GetAvgAP(DataStruct,Axon,PaddingVal,TraceTime,TraceLength)
% Function to get average APs for a particular axon
    % Go through each row of DataStruct to look for average
    AvgAPVals = cell(1,length(DataStruct));
    WidenVal = 0.001; % How far to go past onsets/AHPs in seconds
    WidenVal = Sec2Index(WidenVal,TraceTime,TraceLength);
    for n = 1:length(DataStruct)
        %Get all the indices for that row of the struct
        APsofInterest = find(DataStruct(n).AxonLabels == Axon);
        OnsetIndices = zeros(1,length(APsofInterest));
        AHPIndices = zeros(1,length(APsofInterest));
        for k = 1:length(APsofInterest)
            CurrentWidenVal = round(WidenVal);
            TempOnsetIndex = DataStruct(n).APOnsets{APsofInterest(k)}(2)-CurrentWidenVal;
            TempAHPIndex = DataStruct(n).APAHPs{APsofInterest(k)}(2)+CurrentWidenVal;
            while TempOnsetIndex < 1 || TempAHPIndex > length(TraceTime)
                CurrentWidenVal = round(CurrentWidenVal/2);
                TempOnsetIndex = TempOnsetIndex + CurrentWidenVal;
                TempAHPIndex = TempAHPIndex - CurrentWidenVal;
            end
            OnsetIndices(k) = TempOnsetIndex;
            AHPIndices(k) = TempAHPIndex;
        end
        
        APVals = arrayfun(@(x,y) DataStruct(n).APVals(x:y)',OnsetIndices,AHPIndices,'UniformOutput',false);
        AvgAPVals{n} = mean(AlignAPs(APVals,PaddingVal),1);
    end
    AvgAP = mean(AlignAPs(AvgAPVals,PaddingVal),1);
end

function ParameterValues = GetParameters(DataStruct, Characteristic, CurrentTrace, CurrentAxon, Windowing,TraceTime,TraceLength)
% Function to get parameter values for a particular trace
    TraceIndex = find([DataStruct.Trace] == CurrentTrace);
    if isnan(CurrentAxon)
        switch Characteristic
            case "AHP Amplitudes"
                GrabWindow = cellfun(@(x) x(2) >= Windowing(1) && x(2) <= Windowing(2), DataStruct(TraceIndex).APAHPs)';
                ParameterValues = DataStruct(TraceIndex).APAHPAmplitudes(GrabWindow);
            case "Amplitudes"
                GrabWindow = cellfun(@(x) x(2) >= Windowing(1) && x(2) <= Windowing(2), DataStruct(TraceIndex).APOnsets)';
                ParameterValues = DataStruct(TraceIndex).APAmplitudes(GrabWindow);
            case "Durations"
                GrabWindow = cellfun(@(x) x(2) >= Windowing(1) && x(2) <= Windowing(2), DataStruct(TraceIndex).APOnsets)';
                ParameterValues = DataStruct(TraceIndex).APDurations(GrabWindow);
            case "Frequencies"
                GrabWindow = cellfun(@(x) x(2) >= Windowing(1) && x(2) <= Windowing(2), DataStruct(TraceIndex).APPeaks)';
                FreqInd = cellfun(@(x) x(2), DataStruct(TraceIndex).APPeaks(GrabWindow));
                ParameterValues = 1./diff(Index2Sec(FreqInd,TraceTime,TraceLength));
            case "Interspike Intervals"
                GrabWindow = cellfun(@(x) x(2) >= Windowing(1) && x(2) <= Windowing(2), DataStruct(TraceIndex).APPeaks)';
                SpikeInd = cellfun(@(x) x(2), DataStruct(TraceIndex).APPeaks(GrabWindow));
                ParameterValues = diff(Index2Sec(SpikeInd,TraceTime,TraceLength));
        end
    else
        switch Characteristic
            case "AHP Amplitudes"
                GrabWindow = cellfun(@(x) x(2) >= Windowing(1) && x(2) <= Windowing(2), DataStruct(TraceIndex).APAHPs)';
                ParameterValues = DataStruct(TraceIndex).APAHPAmplitudes((DataStruct(TraceIndex).AxonLabels == CurrentAxon) & GrabWindow);
            case "Amplitudes"
                GrabWindow = cellfun(@(x) x(2) >= Windowing(1) && x(2) <= Windowing(2), DataStruct(TraceIndex).APOnsets)';
                ParameterValues = DataStruct(TraceIndex).APAmplitudes((DataStruct(TraceIndex).AxonLabels == CurrentAxon) & GrabWindow);
            case "Durations"
                GrabWindow = cellfun(@(x) x(2) >= Windowing(1) && x(2) <= Windowing(2), DataStruct(TraceIndex).APOnsets)';
                ParameterValues = DataStruct(TraceIndex).APDurations((DataStruct(TraceIndex).AxonLabels == CurrentAxon) & GrabWindow);
            case "Frequencies"
                GrabWindow = cellfun(@(x) x(2) >= Windowing(1) && x(2) <= Windowing(2), DataStruct(TraceIndex).APPeaks)';
                FreqInd = cellfun(@(x) x(2), DataStruct(TraceIndex).APPeaks((DataStruct(TraceIndex).AxonLabels == CurrentAxon) & GrabWindow));
                ParameterValues = 1./diff(Index2Sec(FreqInd,TraceTime,TraceLength));
            case "Interspike Intervals"
                GrabWindow = cellfun(@(x) x(2) >= Windowing(1) && x(2) <= Windowing(2), DataStruct(TraceIndex).APPeaks)';
                SpikeInd = cellfun(@(x) x(2), DataStruct(TraceIndex).APPeaks((DataStruct(TraceIndex).AxonLabels == CurrentAxon) & GrabWindow));
                ParameterValues = diff(Index2Sec(SpikeInd,TraceTime,TraceLength));
        end
    end
end

function HistogramPlotter(TLayout,ControlStruct,MicrowaveStruct,First,Last,Windowing,Characteristic,TraceTime,TraceLength,OutlierEffect)
% Function that creates paired histograms for each axon within a window
    for CurrentAxon = 1:max(arrayfun(@(x) max(x.AxonLabels), ControlStruct))
        CurrentTile = nexttile(TLayout);
        hold(CurrentTile,'on')
        Parameters.Control = [];
        Parameters.Microwave = [];
        for CurrentTrace = First:Last
            if mod(CurrentTrace,2) ~= 0
                Parameters.Control = [Parameters.Control GetParameters(ControlStruct,Characteristic,CurrentTrace,CurrentAxon,Windowing,TraceTime,TraceLength)];
            else
                Parameters.Microwave = [Parameters.Microwave GetParameters(MicrowaveStruct,Characteristic,CurrentTrace,CurrentAxon,Windowing,TraceTime,TraceLength)];
            end
        end
        
        % Outliers
        PercentileBounds = [10,90];
        if strcmp(OutlierEffect,"Trimmed")
            Parameters.Control = Trimmer(Parameters.Control,PercentileBounds(1),PercentileBounds(2));
            Parameters.Microwave = Trimmer(Parameters.Microwave,PercentileBounds(1),PercentileBounds(2));
        elseif strcmp(OutlierEffect,"Winsorized")
            Parameters.Control = Winsorize(Parameters.Control,PercentileBounds(1),PercentileBounds(2));
            Parameters.Microwave = Winsorize(Parameters.Microwave,PercentileBounds(1),PercentileBounds(2));
        end

        % Plot histograms
        histogram(Parameters.Control,'Normalization','Probability','FaceAlpha',.3,'EdgeColor',AxonColor(CurrentAxon),'FaceColor',AxonColor(CurrentAxon))
        hold on;
        histogram(Parameters.Microwave,'Normalization','Probability','FaceAlpha',.3,'EdgeColor',[1 1 1]-AxonColor(CurrentAxon),'FaceColor',[1 1 1]-AxonColor(CurrentAxon))
        
        % Plot CDFs
        yyaxis right
        [ControlF,ControlX] = ecdf(Parameters.Control);
        [MicrowaveF,MicrowaveX] = ecdf(Parameters.Microwave);
        plot(ControlX,ControlF,'Color',[AxonColor(CurrentAxon) 0.5],'LineWidth',1.5);
        plot(MicrowaveX,MicrowaveF,'LineStyle','--','Color',[1 1 1 0.5]-[AxonColor(CurrentAxon) 0],'LineWidth',1.5)
        
        % KS Testing
        AllX = unique([ControlX', MicrowaveX']);
        [ControlXUnique, ~, ic] = unique(ControlX);
        ControlFMean = accumarray(ic, ControlF, [], @mean);
        ControlFInterp = interp1(ControlXUnique, ControlFMean, AllX,'previous');
        [MicrowaveXUnique, ~, ic] = unique(MicrowaveX);
        MicrowaveFMean = accumarray(ic, MicrowaveF, [], @mean);
        MicrowaveFInterp = interp1(MicrowaveXUnique, MicrowaveFMean, AllX,'previous');
        [KSStat,IdX] = max(abs(ControlFInterp-MicrowaveFInterp));
        [~,P] = kstest2(Parameters.Control,Parameters.Microwave);
        if P < 0.01
            Significance = '**';
        elseif P < 0.05
            Significance = '*';
        else
            Significance = 'NS';
        end
        line(repmat(AllX(IdX),1,2),[ControlFInterp(IdX),MicrowaveFInterp(IdX)],'Color','k','LineStyle',':');
        MedianX = median([Parameters.Control, Parameters.Microwave]);
        yLims = get(gca,'ylim');
        text(MedianX,yLims(1)+0.1*diff(yLims),sprintf('Max CDF %s = %.2f %s',char(916),KSStat,Significance),'HorizontalAlignment','center','FontWeight','Bold')
        Ax = gca;
        Ax.YAxis(1).Color = 'k';
        Ax.YAxis(2).Color = 'k';
        title(sprintf('Axon %d %.2f to %.2f s',CurrentAxon,Index2Sec(Windowing(1),TraceTime,TraceLength),Index2Sec(Windowing(2),TraceTime,TraceLength)),'FontSize',13)
    end
end

function QuadStatsPlot(ParametersStruct, UIFig, FigPosition, ax1, ax2, ax3, ax4)
    APPlotControl = plot(ax1, ParametersStruct.ControlXAxis, [ParametersStruct.ControlAPValsmins; ParametersStruct.ControlAPValsmaxs; ParametersStruct.ControlAPValsmeans; ParametersStruct.ControlAPValsstds], 'LineWidth', 2);
    PSPPlotControl = plot(ax2, ParametersStruct.ControlXAxis, [ParametersStruct.ControlPSPValsmins; ParametersStruct.ControlPSPValsmaxs; ParametersStruct.ControlPSPValsmeans; ParametersStruct.ControlPSPValsstds], 'LineWidth', 2);
    APPlotMicrowave = plot(ax3, ParametersStruct.MicrowaveXAxis, [ParametersStruct.MicrowaveAPValsmins; ParametersStruct.MicrowaveAPValsmaxs; ParametersStruct.MicrowaveAPValsmeans; ParametersStruct.MicrowaveAPValsstds], 'LineWidth', 2);
    PSPPlotMicrowave = plot(ax4, ParametersStruct.MicrowaveXAxis, [ParametersStruct.MicrowavePSPValsmins; ParametersStruct.MicrowavePSPValsmaxs; ParametersStruct.MicrowavePSPValsmeans; ParametersStruct.MicrowavePSPValsstds], 'LineWidth', 2);
    ax1.ColorOrder = [1 0 0; 0.7 0 0; 0.5 0 0; 0.3 0 0];
    ax2.ColorOrder = [0 0 1; 0 0 0.7; 0 0 0.5; 0 0 0.3];
    ax3.ColorOrder = [1 0 0; 0.7 0 0; 0.5 0 0; 0.3 0 0];
    ax4.ColorOrder = [0 0 1; 0 0 0.7; 0 0 0.5; 0 0 0.3];

    % Set titles, legend, grid and labels
    title(ax1, 'Control Action Potentials'); title(ax2, 'Control Postsynaptic Potentials');
    title(ax3, 'Microwave Action Potentials'); title(ax4, 'Microwave Postsynaptic Potentials');
    legend(ax1, 'Min', 'Max', 'Mean', 'SD'); legend(ax2, 'Min', 'Max', 'Mean', 'SD');
    legend(ax3, 'Min', 'Max', 'Mean', 'SD'); legend(ax4, 'Min', 'Max', 'Mean', 'SD');
    xlabel(ax1, 'Trace (#)'); xlabel(ax2, 'Trace (#)'); xlabel(ax3, 'Trace (#)'); xlabel(ax4, 'Trace (#)');
    ylabel(ax1, 'Voltage (V)'); ylabel(ax2, 'Voltage Differential');
    ylabel(ax3, 'Voltage (V)'); ylabel(ax4, 'Voltage Differential');
    grid(ax1, 'on'); grid(ax2, 'on'); grid(ax3, 'on'); grid(ax4, 'on');
    xlim(ax1,'tight'); xlim(ax2,'tight'); xlim(ax3,'tight'); xlim(ax4,'tight');
    
    % Title text
    uilabel(UIFig, 'Text', UIFig.Name, 'Position', [(FigPosition(3)-300)/2 FigPosition(4)-30 300 30], 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 16);
     
    % Plot toggle buttons
    uibutton(UIFig, 'Position', [(FigPosition(3)-350)/2 FigPosition(4)-65-ax1.Position(4)-ax3.Position(4) 80 20], 'Text', 'Toggle Min', 'ButtonPushedFcn', @(btn,event) TogglePlot(1));
    uibutton(UIFig, 'Position', [(FigPosition(3)-350)/2+90 FigPosition(4)-65-ax1.Position(4)-ax3.Position(4) 80 20], 'Text', 'Toggle Max', 'ButtonPushedFcn', @(btn,event) TogglePlot(2));
    uibutton(UIFig, 'Position', [(FigPosition(3)-350)/2+180 FigPosition(4)-65-ax1.Position(4)-ax3.Position(4) 80 20], 'Text', 'Toggle Mean', 'ButtonPushedFcn', @(btn,event) TogglePlot(3));
    uibutton(UIFig, 'Position', [(FigPosition(3)-350)/2+270 FigPosition(4)-65-ax1.Position(4)-ax3.Position(4) 80 20], 'Text', 'Toggle SD', 'ButtonPushedFcn', @(btn,event) TogglePlot(4));

    function TogglePlot(plotIndex)
        APPlotControl(plotIndex).Visible = ~strcmp(APPlotControl(plotIndex).Visible, 'on');
        PSPPlotControl(plotIndex).Visible = ~strcmp(PSPPlotControl(plotIndex).Visible, 'on');
        APPlotMicrowave(plotIndex).Visible = ~strcmp(APPlotMicrowave(plotIndex).Visible, 'on');
        PSPPlotMicrowave(plotIndex).Visible = ~strcmp(PSPPlotMicrowave(plotIndex).Visible, 'on');
    end
    fontname(UIFig,'Century Schoolbook')
end

function RasterPlotter(varargin)
    % Initial configuration
    DataStruct = varargin{1};
    ScreenSize = varargin{2};
    if (mod(DataStruct(1).Trace,2) == 1)
        Identifier = 'Control';
    else
        Identifier = 'Microwave';
    end
    if nargin > 4
        TraceLimit = varargin{3};
        ax = varargin{4};
        GraphingWindow = varargin{5};
        %Limits = varargin{6};
    elseif nargin > 2
        TraceLimit = varargin{3};
        ax = varargin{4};
    else
        TraceLimit = 1:length(DataStruct);
        FigPosition = [(ScreenSize(3)-1200)/2 (ScreenSize(4)-750)/2 1200 750];
        RasterFig = uifigure('Name', sprintf('Labeled %s Raster Plot',Identifier), 'Position', FigPosition);
        fontname(RasterFig,'Century Schoolbook')
        ax = uiaxes(RasterFig, 'Position', [25 50 1000 700]);
    end

    % Raster plotting
    MaxAPNum = max(DataStruct(1).AxonLabels);
    RunningAmpCount = 1;
    for n = TraceLimit
        if nargin < 5
            GraphingWindow = 1:length(DataStruct(n).APAmplitudes);
        end
        AmpVals = DataStruct(n).APAmplitudes(GraphingWindow);
        Labels = DataStruct(n).AxonLabels(GraphingWindow);
        AmpCount = length(AmpVals);
        XReference = RunningAmpCount:RunningAmpCount+AmpCount-1;
        AxonColors = arrayfun(@(x)AxonColor(x),Labels,'UniformOutput',false);
        AxonColors = vertcat(AxonColors{:});
        yyaxis(ax,'left')
        scatter(ax,XReference,AmpVals,10,AxonColors,'filled')
        hold(ax,'on')
        if length(TraceLimit) > 1
            yyaxis(ax,'right')
            Y = repmat(DataStruct(n).Trace,size(XReference));
            line(ax,XReference,Y,'Color',[0.7 0.7 0.7],'LineWidth',3)
            hold(ax,'on')
        end
        RunningAmpCount = RunningAmpCount + AmpCount;
    end
    %title(ax,'Partial Raster Plot','FontSize',15,'FontWeight','Bold')

    if length(TraceLimit) > 1
        if nargin > 2
            %title(ax,'Full Raster Plot','FontSize',15,'FontWeight','Bold')
            %subtitle(ax,'All Traces','FontSize',11)
        else
            %title(ax,sprintf('Labeled %s Raster Plot',Identifier),'FontSize',15,'FontWeight','Bold')
            LegendPlots = gobjects(MaxAPNum+2,1);
            for n = 1:MaxAPNum
                LegendPlots(n+2) = plot(ax,NaN,NaN,'.','Color',AxonColor(n));
                hold(ax,'on')
            end
            LegendPlots(2) = plot(ax,NaN,NaN,'.','Color',AxonColor(NaN));
            LegendPlots(1) = plot(ax,NaN,NaN,'-','Color',[0.7 0.7 0.7]);
            legend(ax,LegendPlots,[{'Trace','Unlabeled'},arrayfun(@(x)['Axon ', num2str(x)],1:MaxAPNum,'UniformOutput',false)],'Location','northwest');
        end
        yyaxis(ax,'right')
        ax.YAxis(2).Color = 'k';
        ylabel(ax,'Trace (#)')
    else
        if nargin > 4
            %subtitle(sprintf('%.2f to %.2f seconds',Limits(1),Limits(2)),'FontSize',11)
        else
            %subtitle(sprintf('Trace %d',DataStruct(TraceLimit).Trace),'FontSize',11)
        end
        yyaxis(ax,'right')
        ax.YAxis(2).Color = 'none';
    end
    xlabel(ax,'Peak Number')
    xlim(ax,'tight')
    yyaxis(ax,'left')
    ylabel(ax,'Amplitude Voltage (V)')
    ax.YAxis(1).Color = 'k';
    grid(ax,'on')

    %Optional ui interface
    if nargin < 3
        yZoomBounds = [NaN NaN];
        uilabel(RasterFig, 'Position', [1030 700 150 20], 'Text', 'Define Y Range:', 'FontWeight', 'bold');
        SetUpperYZoomBtn = uibutton(RasterFig, 'Position', [1030 680 150 20], 'Text', 'Set Upper Y Zoom', 'ButtonPushedFcn', @(btn,event) SetYZoom(btn,ax,1));
        SetLowerYZoomBtn = uibutton(RasterFig, 'Position', [1030 660 150 20], 'Text', 'Set Lower Y Zoom', 'ButtonPushedFcn', @(btn,event) SetYZoom(btn,ax,2));
        ResetYZoomBtn = uibutton(RasterFig, 'Position', [1030 640 150 20], 'Text', 'Reset Y Zoom', 'ButtonPushedFcn', @(btn,event) ResetYZoom(btn,ax,SetUpperYZoomBtn,SetLowerYZoomBtn));
        uilabel(RasterFig,'Position',[1030 610 150 20],'Text','Define Trace Window:','FontWeight','bold');
        FirstTraceNum = uidropdown(RasterFig,'Position',[1030 590 150 20],'Items',cellfun(@num2str, {DataStruct(:).Trace}, 'UniformOutput', false));
        LastTraceNum = uidropdown(RasterFig,'Position',[1030 570 150 20],'Items',cellfun(@num2str, {DataStruct(:).Trace}, 'UniformOutput', false));
        ConfirmTraceZoomBtn = uibutton(RasterFig,'Position',[1030 550 150 20],'Text','Set Trace Window','ButtonPushedFcn',@(btn,event)ConfirmXZoom(btn,ax,FirstTraceNum.Value,LastTraceNum.Value));
        ResetTraceZoomBtn = uibutton(RasterFig,'Position',[1030 530 150 20],'Text','Reset Trace Zoom','ButtonPushedFcn',@(btn,event)ResetXZoom(btn,ax,ConfirmTraceZoomBtn));
    end

    function SetYZoom(btn,ax,Index)
        btn.Enable = 'off';
        OriginalText = btn.Text;
        T = timer('TimerFcn',{@UpdateText, btn},'Period',1,'ExecutionMode','FixedRate');
        start(T)
        ax.ButtonDownFcn = @(ax,event) CaptureClick(ax,event,btn,OriginalText,Index,T,ResetYZoomBtn);
    end

    function ResetYZoom(btn,ax,SetUpperYZoomBtn,SetLowerYZoomBtn)
        ylim(ax,'auto');
        btn.Enable = 'off';
        SetUpperYZoomBtn.Enable = 'on';
        SetLowerYZoomBtn.Enable = 'on';
        yZoomBounds = [NaN NaN];
    end

    function CaptureClick(ax,event,btn,OriginalText,Index,T,ResetYZoomBtn)
        Coordinates = event.IntersectionPoint;
        yZoomBounds(Index) = Coordinates(2);
        stop(T)
        delete(T);
        btn.Text = OriginalText;
        ax.ButtonDownFcn = '';
        if all(~isnan(yZoomBounds))
            yyaxis(ax, 'left');
            ylim(ax,[min(yZoomBounds) max(yZoomBounds)]);
            ResetYZoomBtn.Enable = 'on';
        end
    end

    function ConfirmXZoom(btn, ax, FirstTrace, LastTrace)
        FirstTrace = str2double(FirstTrace);
        LastTrace = str2double(LastTrace);
        FirstTraceStart = find([DataStruct.Trace] == FirstTrace, 1, 'first');
        LastTraceEnd = find([DataStruct.Trace] == LastTrace, 1, 'last');
        if ~isempty(FirstTraceStart) && ~isempty(LastTraceEnd)
            FirstTraceStart = sum(arrayfun(@(x) length(x.APAmplitudes), DataStruct(1:FirstTraceStart-1))) + 1;
            LastTraceEnd = sum(arrayfun(@(x) length(x.APAmplitudes), DataStruct(1:LastTraceEnd)));
            yl = ylim(ax);
            xlim(ax, [FirstTraceStart, LastTraceEnd]);
            ylim(ax,yl);
            btn.Enable = 'off';
            ResetTraceZoomBtn.Enable = 'on';
        end
    end

    function ResetXZoom(btn, ax, ConfirmTraceZoomBtn)
        xlim(ax, 'auto');
        btn.Enable = 'off';
        ConfirmTraceZoomBtn.Enable = 'on';
    end

    function UpdateText(~,~,btn)
        CurrentText = btn.Text;
        if strcmp(CurrentText, 'Selecting')
            NextText = 'Selecting.';
        elseif strcmp(CurrentText, 'Selecting.')
            NextText = 'Selecting..';
        elseif strcmp(CurrentText, 'Selecting..')
            NextText = 'Selecting...';
        else
            NextText = 'Selecting';
        end
        btn.Text = NextText;
    end
end

function RasterProcessDisp(DataStruct,ScreenSize,WindowStart,TraceTime,TraceLength)
% Function that creates a three panel example of the raster plot process    
    ProcessFig = figure('Name','Raster Process','Position',[(ScreenSize(3)-1800)/2 (ScreenSize(4)-1000)/2 1800 1000]);
    TLayout = tiledlayout(ProcessFig,1,8);

    % Creates labeled segment plot
    nexttile(TLayout,[1 3])
    plot(TraceTime,DataStruct(1).APVals,'Color',[0 0 1])
    %title(sprintf('Labeled Trace %d',DataStruct(1).Trace),'FontSize',15,'FontWeight','Bold')
    Limits = [Index2Sec(WindowStart,TraceTime,TraceLength)-0.25 Index2Sec(WindowStart,TraceTime,TraceLength)+0.25];
    %subtitle(sprintf('%.2f to %.2f seconds',Limits(1),Limits(2)),'FontSize',11)
    hold on
    for n = 1:length(DataStruct(1).APOnsets)
        StartPoint = DataStruct(1).APOnsets{n}(2);
        EndPoint = DataStruct(1).APAHPs{n}(2);
        plot(TraceTime(StartPoint:EndPoint),DataStruct(1).APVals(StartPoint:EndPoint),'Color',AxonColor(DataStruct(1).AxonLabels(n)))
    end
    xlim(Limits)
    ylim('padded')
    yLimits = ylim;
    patch('XData', [TraceTime(1) Index2Sec(WindowStart,TraceTime,TraceLength) Index2Sec(WindowStart,TraceTime,TraceLength) TraceTime(1)],'YData',[yLimits(1) yLimits(1) yLimits(2) yLimits(2)],'FaceColor',[0.9 0.2 0.2],'FaceAlpha',0.5,'EdgeColor','none')
    xlabel('Time (s)')
    ylabel('Membrane Potential Difference (V)')
    grid on

    % Creates segment labeled partial trace raster plot
    SegmentRaster = nexttile(TLayout);
    ILimits = Sec2Index(Limits,TraceTime,TraceLength);
    GraphingWindow = find(cellfun(@(x) x(2) >= ILimits(1) && x(2) <=ILimits(2),DataStruct(1).APOnsets));
    RasterPlotter(DataStruct,ScreenSize,1,SegmentRaster,GraphingWindow,Limits);

    % Creates segment labeled full trace raster plot
    PartialRaster = nexttile(TLayout);
    RasterPlotter(DataStruct,ScreenSize,1,PartialRaster);

    % Creates full labeled raster plot
    FullRaster = nexttile(TLayout,[1 3]);
    RasterPlotter(DataStruct,ScreenSize,1:length(DataStruct),FullRaster);
    yLimits = ylim(FullRaster);
    ylim(SegmentRaster,yLimits)
    ylim(PartialRaster,yLimits)

    % Configure tiledlayout
    %title(TLayout,'Figure: Labeling Process via Raster Plot','FontSize',17,'FontWeight','Bold')
    hold(FullRaster,'on')
    LegendPlots = gobjects(max(DataStruct(1).AxonLabels)+3,1);
    for n = 1:max(DataStruct(1).AxonLabels)
        LegendPlots(n+3) = plot(FullRaster,NaN,NaN,'LineStyle','none','Marker','.','MarkerSize',25,'Color',AxonColor(n));
    end
    LegendPlots(3) = plot(FullRaster,NaN,NaN,'LineStyle','none','Marker','.','MarkerSize',25,'Color',AxonColor(NaN));
    LegendPlots(2) = line(FullRaster,NaN,NaN,'LineWidth',6,'Color',[0.7 0.7 0.7]);
    LegendPlots(1) = plot(FullRaster,NaN,NaN,'LineStyle','none','Marker','Square','MarkerSize',18,'MarkerFaceColor',[0.9 0.2 0.2],'MarkerEdgeColor','none');
    LegendEntries = [{'Microwave Region','Trace','Unlabeled'},arrayfun(@(x)['Axon ', num2str(x)],1:max(DataStruct(1).AxonLabels),'UniformOutput',false)];
    LegendT = legend(FullRaster,LegendPlots,LegendEntries(:),'NumColumns',max(DataStruct(1).AxonLabels)+3,'FontSize',10);
    LegendT.Layout.Tile = 'South';
    fontname(ProcessFig,'Century Schoolbook')
    fontsize(ProcessFig,scale=1.55)
end

function StabilityPlot(ParametersStruct,ScreenSize)
% Function that displays a stability plot as part of the access menu
    FigPosition = [(ScreenSize(3)-1000)/2 (ScreenSize(4)-700)/2 1000 700];
    SPlot = uifigure('Name', 'Trace Stability Plots', 'Position', FigPosition);
    ax1 = uiaxes('Parent', SPlot, 'Position', [50 370 450 300]);
    ax2 = uiaxes('Parent', SPlot, 'Position', [500 370 450 300]);
    ax3 = uiaxes('Parent', SPlot, 'Position', [50 60 450 300]);
    ax4 = uiaxes('Parent', SPlot, 'Position', [500 60 450 300]);
    QuadStatsPlot(ParametersStruct, SPlot, FigPosition, ax1, ax2, ax3, ax4);
end

function StatsDisp(ScreenSize,ControlStruct,MicrowaveStruct,FigureType,Increments,NewTraceLength,WindowStart,TraceTime,TraceLength,Characteristic,First,Last,OutlierEffect)
% Function for creating various segmented statistical figures
    StatsFig = figure('Name','Stats Plots','Position',[(ScreenSize(3)-1600)/2 (ScreenSize(4)-900)/2 1600 900]);
    Spacing = regexp(Increments,'([\d\.]+) s','tokens');
    Spacing = str2double(Spacing{1});
    Segments = floor(NewTraceLength/Spacing);
    MaxAxons = max(arrayfun(@(x) max(x.AxonLabels), ControlStruct));
    if strcmp(FigureType,"Violin Plots")
        %SaveSymbol = "V";
        StatsFunc = @ViolinPlotter;
        if Segments == 6
            TileCols = 3;
            TileRows = 2;
        elseif Segments > 5
            TileCols = 5;
            TileRows = ceil(Segments/TileCols);
        else
            TileCols = Segments;
            TileRows = 1;
        end
        while TileCols < TileRows && TileCols > 1
            TileCols = TileCols - 1;
            TileRows = ceil(Segments/TileCols);
        end
    elseif strcmp(FigureType,"Histograms")
        %SaveSymbol = "H";
        StatsFunc = @HistogramPlotter;
        TileCols = MaxAxons;
        TileRows = Segments;
    end
    TLayout = tiledlayout(StatsFig,TileRows,TileCols,'TileSpacing','Compact');
    SpacingIndex = Sec2Index(Spacing,TraceTime,TraceLength);
    for q = 1:Segments
        Windowing = [WindowStart WindowStart+SpacingIndex];
        StatsFunc(TLayout,ControlStruct,MicrowaveStruct,First,Last,Windowing,Characteristic,TraceTime,TraceLength,OutlierEffect)
        WindowStart = WindowStart + SpacingIndex;
    end
    title(TLayout,sprintf('Action Potential %s for Axons 1 - %d',Characteristic,MaxAxons),'FontSize',15,'FontWeight','Bold')
    if strcmp(FigureType,"Histograms")
        ylabel(TLayout,sprintf('%s Count',Characteristic))
        LegendPlots = gobjects(MaxAxons*2,1);
        LegendEntries = cell(1, MaxAxons*2);
        for n = 1:MaxAxons
            LegendPlots(n*2-1) = plot(gca,NaN,NaN,'LineStyle','none','Marker','.','MarkerSize',20,'Color',AxonColor(n));
            LegendEntries{n*2-1} = ['Control Axon ', num2str(n)];
            
            LegendPlots(n*2) = plot(gca,NaN,NaN,'LineStyle','none','Marker','.','MarkerSize',20,'Color',[1 1 1]-AxonColor(n));
            LegendEntries{n*2} = ['Microwave Axon ', num2str(n)];
        end
        LegendT = legend(gca,LegendPlots,LegendEntries,'NumColumns',MaxAxons,'FontSize',12);
        LegendT.Layout.Tile = 'North';
        switch Characteristic
            case "AHP Amplitudes"
                xlabel(TLayout,'Voltage (V)')
            case "Amplitudes"
                xlabel(TLayout,'Voltage (V)')
            case "Frequencies"
                xlabel(TLayout,'Amplitude Hz')
            case "Durations"
                xlabel(TLayout,'Time (s)')
            case "Interspike Intervals"
                xlabel(TLayout,'Time (s)')
        end
    end
    fontname(StatsFig,'Century Schoolbook')
    %FileName = sprintf('%s %.1f %s-%s.png',Characteristic,Spacing,SaveSymbol,OutlierEffect);
    %exportgraphics(StatsFig,FileName);
end

function TraceDisp(SelectedTrace,ControlStruct,MicrowaveStruct,TraceTime,ScreenSize,Labeling)
% Function to display paired APs and PSPs with an option for labeling  
    SelectedTrace = str2double(SelectedTrace);
    if mod(SelectedTrace,2) == 1
        DataStruct = ControlStruct;
    else
        DataStruct = MicrowaveStruct;
    end
    TraceFigure = figure('Name',sprintf('AP & PSP %d',SelectedTrace),'Position',[(ScreenSize(3)-1400)/2 (ScreenSize(4)-600)/2 1400 600]);
    T = tiledlayout(1,2);
    
    ax1 = nexttile;
    plot(TraceTime,DataStruct([DataStruct.Trace]==SelectedTrace).APVals,'Color',[0 0 1])
    if Labeling
        hold on
        for n = 1:length(DataStruct([DataStruct.Trace]==SelectedTrace).APOnsets)
            StartPoint = DataStruct([DataStruct.Trace]==SelectedTrace).APOnsets{n}(2);
            EndPoint = DataStruct([DataStruct.Trace]==SelectedTrace).APAHPs{n}(2);
            plot(TraceTime(StartPoint:EndPoint),DataStruct([DataStruct.Trace]==SelectedTrace).APVals(StartPoint:EndPoint),'Color',AxonColor(DataStruct([DataStruct.Trace]==SelectedTrace).AxonLabels(n)))
        end
    end
    title(sprintf('AP %d',SelectedTrace),'FontSize',14,'FontWeight','bold')
    xlim('tight')
    ylabel('Membrane Potential Difference (V)')
    grid on
    ax2 = nexttile;
    plot(TraceTime,DataStruct([DataStruct.Trace]==SelectedTrace).PSPVals,'Color',[0.69 0.17 0.95])
    title(sprintf('PSP %d',SelectedTrace),'FontSize',14,'FontWeight','bold')
    xlim('tight')
    ylabel('Voltage Differential (V)')
    grid on
    xlabel(T,'Time (s)')
    linkaxes([ax1, ax2], 'x');
    fontname(TraceFigure,'Century Schoolbook')
end

function ViolinPlotter(TLayout,ControlStruct,MicrowaveStruct,First,Last,Windowing,Characteristic,TraceTime,TraceLength,OutlierEffect)
% Function that creates paired control/microwave violin plots for each axon
    CurrentTile = nexttile(TLayout);
    hold(CurrentTile,'on')
    Significance = cell(1, max(arrayfun(@(x) max(x.AxonLabels), ControlStruct)));
    MaxYValues = zeros(1, max(arrayfun(@(x) max(x.AxonLabels), ControlStruct)));
    MinYValues = zeros(1, max(arrayfun(@(x) max(x.AxonLabels), ControlStruct)));

    % Grabbing parameter values
    for CurrentAxon = 1:max(arrayfun(@(x) max(x.AxonLabels), ControlStruct))
        Parameters.Control = [];
        Parameters.Microwave = [];
        for CurrentTrace = First:Last
            if mod(CurrentTrace,2) ~= 0
                Parameters.Control = [Parameters.Control GetParameters(ControlStruct, Characteristic, CurrentTrace, CurrentAxon, Windowing,TraceTime,TraceLength)];
            else
                Parameters.Microwave = [Parameters.Microwave GetParameters(MicrowaveStruct, Characteristic, CurrentTrace, CurrentAxon, Windowing,TraceTime,TraceLength)];
            end
        end

        % Outliers
        PercentileBounds = [10,90];
        if strcmp(OutlierEffect,"Trimmed")
            Parameters.Control = Trimmer(Parameters.Control,PercentileBounds(1),PercentileBounds(2));
            Parameters.Microwave = Trimmer(Parameters.Microwave,PercentileBounds(1),PercentileBounds(2));
        elseif strcmp(OutlierEffect,"Winsorized")
            Parameters.Control = Winsorize(Parameters.Control,PercentileBounds(1),PercentileBounds(2));
            Parameters.Microwave = Winsorize(Parameters.Microwave,PercentileBounds(1),PercentileBounds(2));
        end

        %Creating violin plot fills
        [ControlDensity,ControlXVals] = ksdensity(Parameters.Control);
        [MicrowaveDensity,MicrowaveXVals] = ksdensity(Parameters.Microwave);
        ControlX = CurrentAxon*2.5-1;
        MicrowaveX = CurrentAxon*2.5;
        fill([ControlDensity/max(ControlDensity)/2+ControlX, fliplr(-ControlDensity/max(ControlDensity)/2+ControlX)], [ControlXVals, fliplr(ControlXVals)], AxonColor(CurrentAxon), 'EdgeColor', 'Black', 'LineWidth', 1.25)
        fill([MicrowaveDensity/max(MicrowaveDensity)/2+MicrowaveX, fliplr(-MicrowaveDensity/max(MicrowaveDensity)/2+MicrowaveX)], [MicrowaveXVals, fliplr(MicrowaveXVals)], AxonColorM(CurrentAxon), 'EdgeColor', 'Black', 'LineWidth', 1.25)

        % Adding statisticall points
        scatter(ControlX,mean(Parameters.Control),'o','filled','MarkerFaceColor',[1 1 1],'MarkerEdgeColor',[0 0 0])
        scatter(MicrowaveX,mean(Parameters.Microwave),'o','filled','MarkerFaceColor',[1 1 1],'MarkerEdgeColor',[0 0 0])
        QuartilesControl = quantile(Parameters.Control, [0.25 0.5 0.75]);
        QuartilesMicrowave = quantile(Parameters.Microwave, [0.25 0.5 0.75]);        
        ControlWidths = interp1(ControlXVals, ControlDensity, QuartilesControl, 'linear', 'extrap') / max(ControlDensity) / 2;
        MicrowaveWidths = interp1(MicrowaveXVals, MicrowaveDensity, QuartilesMicrowave, 'linear', 'extrap') / max(MicrowaveDensity) / 2;
        for i = 1:3
            line([ControlX-ControlWidths(i), ControlX+ControlWidths(i)], [QuartilesControl(i), QuartilesControl(i)], 'Color', 'Black', 'LineStyle', '-.', 'LineWidth', 1); 
            line([MicrowaveX-MicrowaveWidths(i), MicrowaveX+MicrowaveWidths(i)], [QuartilesMicrowave(i), QuartilesMicrowave(i)], 'Color', 'Black', 'LineStyle', '-.', 'LineWidth', 1);
        end
        
        % Perform Wilcoxon signed rank test
        P = ranksum(Parameters.Control, Parameters.Microwave);
        if P < 0.01
            Significance{CurrentAxon} = '**';
        elseif P < 0.05
            Significance{CurrentAxon} = '*';
        else
            Significance{CurrentAxon} = 'NS';
        end
        
        % Store y-axis scale based on IQR percentiles
        MaxYValues(CurrentAxon) = max([QuartilesControl(3), QuartilesMicrowave(3)]);
        MinYValues(CurrentAxon) = min([QuartilesControl(1), QuartilesMicrowave(1)]);
    end
    Labels = arrayfun(@(x) {sprintf('Axon %d Control',x), sprintf('Axon %d Microwave',x)}, 1:max(arrayfun(@(x) max(x.AxonLabels), ControlStruct)), 'UniformOutput',false);
    Labels = [Labels{:}];
    set(gca, 'XTick', sort([(1:1:max(arrayfun(@(x) max(x.AxonLabels), ControlStruct)))*2.5-1, (1:1:max(arrayfun(@(x) max(x.AxonLabels), ControlStruct)))*2.5]), 'XTickLabel', Labels, 'YGrid', 'on', 'TickDir', 'out');
    switch Characteristic
        case "AHP Amplitudes"
            ylabel('Voltage (V)')
        case "Amplitudes"
            ylabel('Voltage (V)')
        case "Durations"
            ylabel('Time (s)')
        case "Frequencies"
            ylabel('Amplitude Hz')
        case "Interspike Intervals"
            ylabel('Seconds (s)')
    end
    title(sprintf('%.2f to %.2f s',Index2Sec(Windowing(1),TraceTime,TraceLength),Index2Sec(Windowing(2),TraceTime,TraceLength)),'FontSize',13)

    % Compare axon independent characteristic
    ControlCompiled = [];
    MicrowaveCompiled = [];
    for CurrentTrace = First:Last
        if mod(CurrentTrace,2) ~= 0
            ControlCompiled = [ControlCompiled GetParameters(ControlStruct,Characteristic,CurrentTrace,NaN,Windowing,TraceTime,TraceLength)]; %#ok<AGROW>
        else
            MicrowaveCompiled = [MicrowaveCompiled GetParameters(MicrowaveStruct,Characteristic,CurrentTrace,NaN,Windowing,TraceTime,TraceLength)]; %#ok<AGROW>
        end
    end
    P = ranksum(ControlCompiled, MicrowaveCompiled);
    if P < 0.01
        subtitle('**','FontWeight','Bold','FontSize',10);
    elseif P < 0.05
        subtitle('*','FontWeight','Bold','FontSize',10);
    else
        subtitle('NS','FontSize',10);
    end

    % Label significance
    NewUpperYLimit = max(MaxYValues) + 0.4*abs(max(MaxYValues));
    NewLowerYLimit = min(MinYValues) - 0.4*abs(min(MinYValues));
    set(gca, 'ylim', [NewLowerYLimit, NewUpperYLimit]);
    set(gca, 'xlim', [0.5, max(arrayfun(@(x) max(x.AxonLabels), ControlStruct))*2.5 + 0.5]);
    for CurrentAxon = 1:max(arrayfun(@(x) max(x.AxonLabels), ControlStruct))
        ControlX = CurrentAxon*2.5-1;
        MicrowaveX = CurrentAxon*2.5;
        midPointX = (ControlX + MicrowaveX) / 2;
        NewY = MaxYValues(CurrentAxon) + (0.2 * (max(MaxYValues) - min(MinYValues)));
        line([ControlX, MicrowaveX], [NewY, NewY], 'Color', 'k', 'LineStyle', '-', 'LineWidth', 1.5);
        text(midPointX, NewY, Significance{CurrentAxon}, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    end
end