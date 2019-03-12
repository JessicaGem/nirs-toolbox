function data = loadDotNirs( filenames )

% if a single filename, put it in a cell
if ischar( filenames )
    filenames = {filenames};
end

data = nirs.core.Data.empty;
cnt=1;
% iterate through cell array
for iFile = 1:length(filenames)
    try
        [hdr,d]=readSOMMAheader(filenames{iFile});
        for i=1:length(d)
            data(cnt)=parseData(hdr(i),d{i});
            data(cnt).description=filenames{iFile};
            cnt=cnt+1;
        end
    end
  
end


end


function [hdr,data] = readSOMMAheader(filename)

fid=fopen(filename,'r');
hdr=struct('start',NaN,'nrows',NaN,'line','','ncols',5,'marks',[]);
cnt=0; data={};
while(~feof(fid))
    hdr(end+1)=struct('start',NaN,'nrows',NaN,'line','','ncols',5,'marks',[]);
    dd={};
    while(1)
        line=fgetl(fid);
        cnt=cnt+1;
        if(~isempty(strfind(line,'<DATA>')))
            break;
        end
        hdr(end).line=strvcat(hdr(end).line,line);
        if(feof(fid)); break; end
    end
    hdr(end).start=cnt;
    cnt2=cnt;
    while(1)
        line=fgetl(fid);
        cnt2=cnt2+1;
        if(~isempty(strfind(line,'MARK')))
            hdr(end).marks(end+1)=str2num(line(1:strfind(line,',')));
        elseif(~isempty(strfind(line,'</DATA>')))
            break;
        else
            dd{end+1}=[line ','];
        end
        
       
        % cnt=cnt+1;
        if(feof(fid)); break; end
    end
    str=strcat(dd{:});
    str(strfind(str,','))=' ';
    c=sscanf(str,'%f');
    c=c(1:floor(size(c,1)/6)*6);
    data{end+1}=reshape(c,6,[])';
    hdr(end).nrows=cnt2-cnt;
    cnt=cnt2;
end
fclose(fid);
hdr(1)=[];



for i=1:length(hdr)
    hdr(i).info=gethdrinfo(hdr(i));
    hdr(i).info.scan=i;
end


end

function info=gethdrinfo(hdr)

info=[];
for i=1:size(hdr.line)
    if(~isempty(strfind(hdr.line(i,:),'subjid')))
        info.SubjID=hdr.line(i+1,:);
        info.SubjID=strtrim(info.SubjID);
    end
    if(~isempty(strfind(hdr.line(i,:),'session')))
        info.Session=hdr.line(i+1);
        info.Session=strtrim(info.Session);
    end
    if(~isempty(strfind(hdr.line(i,:),'date')))
        info.Date=hdr.line(i+1,:);
        info.Date=strtrim(info.Date);
    end
    if(~isempty(strfind(hdr.line(i,:),'site')))
        info.Site=hdr.line(i+1,:);
        info.Site=strtrim(info.Site);
    end
    if(~isempty(strfind(hdr.line(i,:),'deviceid')))
        info.DeviceID=hdr.line(i+1,:);
        info.DeviceID=strtrim(info.DeviceID);
    end
    if(~isempty(strfind(hdr.line(i,:),'comments')))
        info.Comments=hdr.line(i+1,:);
        info.Comments=strtrim(info.Comments);
    end
end
end


function data=parseData(hdr,d)
data = nirs.core.Data;

for i=3:6
    dd=medfilt1(d(:,i),3);
    for j=2:size(dd,1)-1; 
        d1(j,i-2)=min(dd(j-1:j+1)); 
        d2(j,i-2)=max(dd(j-1:j+1)); 
    end;
end
d1=medfilt1(d1,11);
d2=medfilt1(d2,11);

fs=1000./mean(diff(d(:,1)));
[fa,fb]=butter(4,10*2/fs);
d1=filtfilt(fa,fb,d1);
d2=filtfilt(fa,fb,d2);

t=d(1:end-1,1);
fs=fix(fs*50)/50;
time=t(1)/1000:1/fs:t(end-2)/1000;


for i=1:size(d1,2)
    dd1(:,i)=interp1(t/1000,d1(:,i),time,'spline','extrap');
    dd2(:,i)=interp1(t/1000,d2(:,i),time,'spline','extrap');
end
dd2=2^12-dd2;
dd1=2^12-dd1;
% 
% dd1=dd2-dd1;


srcPos=[0 0 0];
detPos=[0 10 0;
    0 20 0;
    0 30 0;
    0 40 0];
source=ones(8,1);
detector=[1:4 1:4]';
type=[780 780 780 780 850 850 850 850]';
link=table(source,detector,type);

data.probe=nirs.core.Probe( srcPos, detPos, link );

if(~isempty(hdr.marks))
    stim=nirs.design.StimulusEvents;
    onsets=hdr.marks/1000-time(1);
    dur=2*ones(size(onsets));
    amp=ones(size(onsets));
    stim.name='Mark'; stim.onset=onsets; stim.dur=dur; stim.amp=amp;
    data.stimulus('Mark')=stim;
end
data.time=time-time(1);
data.data=[dd2 dd1];
data.demographics('subject')=hdr.info.SubjID;
data.demographics('date')=hdr.info.Date;
data.demographics('site')=hdr.info.Site;
data.demographics('device')=hdr.info.DeviceID;
data.demographics('session')=hdr.info.Session;
data.auxillary('comments')=hdr.info.Comments;

end
