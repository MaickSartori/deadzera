#!/bin/bash

set -e
echo "Version OTHEVCLOW-2.77-0009"

if ! which bc > /dev/null 2>&1; then
    echo "BC not installed"
    apt install -y bc
fi

# Usage create-vod-hls.sh SOURCE_FILE [OUTPUT_NAME]
[[ ! "${1}" ]] && echo "Usage: " && exit 1

# comment/add lines here to control which renditions would be created
renditions=(
# resolution  bitrate  audio-rate
  #"320x180    450k     64k"
  #"384x216    480k     64k"
  #"512x288    500k     64k"
  "640x360    700k     64k"
  #"768x432    800k     96k"  
  #"864x486    900k     96k"
  #"960x540    900k     96k"
  #"1024x576   1100k    96k"
  "1280x720   2900k    96k"
  #"1920x1080   2200k    96k"
  #"4096x2160   3800k    96k"
)
####renditions="$(echo `curl -s http://epgbr.com.br/renditions.php`)"
segment_target_duration=4       # try to create a new segment every X seconds
max_bitrate_ratio=1.5          # maximum accepted bitrate fluctuations
rate_monitor_buffer_ratio=1.5   # maximum buffer size between bitrate conformance checks
ratio_video=1.6
#########################################################################

UDP="?overrun_nonfatal=1&fifo_size=758000&buffer_size=758000&timeout=300"
TESTE=`echo ${2} | cut -d":" -f1`
if [ $TESTE == udp ]; then
MULTCAST=${2}${UDP}
else
MULTCAST=${2}
fi

if  [ $9 == 2 ]; then
FINAL_AUDIO=":0 -map 0:a:1"
else
FINAL_AUDIO=$9
fi

source="${MULTCAST}"
target="/usr/local/nginx/html/live/${1}"
if [[ ! "${target}" ]]; then
  target="${source##*/}" # leave only last component of path
  target="${target%.*}"  # strip extension
fi
mkdir -p ${target}

#killall -9 ${1}
INPUT=${4}
OUTFORMAT=${5}

# static parameters that are similar for all renditions
###-vstats_file $1.txt
static_params="  -aspect 16:9 -pixel_format cuda -map 0:v:0 -c:v $OUTFORMAT -profile:v main -sc_threshold 0 -map 0:s? -scodec copy"
static_params+=" -max_muxing_queue_size 4096 -g 60 -keyint_min 90 -hls_time ${segment_target_duration}"
static_params+=" -fflags +genpts -segment_time 6 -segment_list_size 10 -hls_flags delete_segments -segment_list_flags +live -individual_header_trailer 0 -segment_list_type m3u8"
# misc params
misc_params=" -re -y -nostats -nostdin -v level+error -stats -err_detect ignore_err -analyzeduration 9000000 -probesize 9000000 -fflags +genpts -hide_banner -threads 0 -hwaccel_device ${10} -hwaccel cuvid -c:v $INPUT -canvas_size 1920x1080 -resize 1280x720 -deint 2 -fix_sub_duration -drop_second_field true -ignore_unknown "

master_playlist="#EXTM3U
#EXT-X-VERSION:3\n"
if  [ $9 == 2 ]; then
master_playlist+="#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"group_audio\",NAME=\"English\",DEFAULT=NO,LANGUAGE=\"Eng\",URI=\"720p_audio_en.m3u8\"\n"
master_playlist+="#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"group_audio\",NAME=\"Portuguese\",DEFAULT=YES,LANGUAGE=\"Por\",URI=\"720p_audio_pt.m3u8\"\n"
    else
master_playlist+="#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"group_audio\",NAME=\"Portuguese\",DEFAULT=YES,LANGUAGE=\"Por\",URI=\"720p_audio_pt.m3u8\"\n"
fi
      
cmd=""
for rendition in "${renditions[@]}"; do
  # drop extraneous spaces
  rendition="${rendition/[[:space:]]+/ }"
  # rendition fields
  resolution="$(echo ${rendition} | cut -d ' ' -f 1)"
  bitrate="$(echo ${rendition} | cut -d ' ' -f 2)"
  audiorate="$(echo ${rendition} | cut -d ' ' -f 3)"
  # calculated fields
  width="$(echo ${resolution} | grep -oE '^[[:digit:]]+')"
  height="$(echo ${resolution} | grep -oE '[[:digit:]]+$')"
  maxrate="$(echo "`echo ${bitrate} | grep -oE '[[:digit:]]+'`*135/100" | bc)"
  bufsize="$(echo "`echo ${bitrate} | grep -oE '[[:digit:]]+'`*175/100" | bc)"
  bandwidth="$(echo ${bitrate} | grep -oE '[[:digit:]]+')000"
  Bandwidth="$(echo "`echo ${bitrate} | grep -oE '[[:digit:]]+'`*140/100" | bc)000"
  #bandwidth="$(echo ${maxrate} | grep -oE '[[:digit:]]+')000"
  name="${height}p"
  static_a2="-map 0:a:0 -c:a aac -ac 2 -ar 48000 -b:a ${audiorate} -af "volume=-10dB" -fflags +genpts -segment_time 6 -segment_list_size 10 -hls_flags delete_segments -segment_list_flags +live -individual_header_trailer 0 -segment_list_type m3u8 -g 60 -keyint_min 90 -hls_time ${segment_target_duration} "
if [ $1 == WB ]; then
  static_a0="-map 0:a:m:language:por -c:a aac -ac 2 -ar 48000 -b:a ${audiorate} -af "volume=-10dB" -fflags +genpts -segment_time 6 -segment_list_size 10 -hls_flags delete_segments -segment_list_flags +live -individual_header_trailer 0 -segment_list_type m3u8 -g 60 -keyint_min 60 -hls_time ${segment_target_duration} "
else
  static_a0="-map 0:a:m:language:por -c:a aac -ac 2 -ar 48000 -b:a ${audiorate} -af "volume=-10dB" -fflags +genpts -segment_time 6 -segment_list_size 10 -hls_flags delete_segments -segment_list_flags +live -individual_header_trailer 0 -segment_list_type m3u8 -g 60 -keyint_min 60 -hls_time ${segment_target_duration} "
fi	
  static_a1="-map 0:a:m:language:eng -c:a aac -ac 2 -ar 48000 -b:a ${audiorate} -af "volume=-10dB" -fflags +genpts -segment_time 6 -segment_list_size 10 -hls_flags delete_segments -segment_list_flags +live -individual_header_trailer 0 -segment_list_type m3u8 -g 60 -keyint_min 90 -hls_time ${segment_target_duration} "
  #cmd+=" ${static_params} -vf scale=w=${width}:h=${height}:force_original_aspect_ratio=decrease"
  #cmd+=" ${static_params} -filter:v scale_npp=-${width}:${height},hwdownload,format=nv12 -filter:a "volume=15dB""
  cmd+=" -max_muxing_queue_size 4096 ${static_params} -filter_complex [0:v:0]scale_npp=format=yuv420p,scale_npp=${width}:${height}:interp_algo=super:force_original_aspect_ratio=decrease -avoid_negative_ts make_zero -fflags +genpts"
  cmd+=" -b:v ${bitrate} -maxrate ${maxrate%.*}k -bufsize ${bufsize%.*}k "
  cmd+=" -f segment -segment_list ${target}/${name}.m3u8 ${target}/${name}_%09d.ts "
if  [ $9 == 2 ]; then
  cmd+=" ${static_a0}  -f segment -segment_list ${target}/${name}_audio_pt.m3u8 ${target}/${name}_audio_pt_%09d.ts "
  cmd+=" ${static_a1}  -f segment -segment_list ${target}/${name}_audio_en.m3u8 ${target}/${name}_audio_en_%09d.ts "
else
  cmd+=" ${static_a2}  -f segment -segment_list ${target}/${name}_audio_pt.m3u8 ${target}/${name}_audio_pt_%09d.ts "
fi  
  
  # add rendition entry in the master playlist
  master_playlist+="#EXT-X-STREAM-INF:BANDWIDTH=${Bandwidth},AUDIO=\"group_audio\",RESOLUTION=${resolution},CODECS=\"avc1.4d001e,mp4a.40.2\"\n${name}.m3u8\n"
done

# create master playlist file
#echo -e "${Bandwidth}"
echo -e "${master_playlist}" > ${target}/playlist.m3u8
# start conversion

##echo -e "Executing command:\nffmpeg ${misc_params} -i ${source} ${cmd}"
cp /opt/iptv/bin/ffmpeg /opt/iptv/bin/${1}
/opt/iptv/bin/${1} ${misc_params} -i ${source} ${cmd} > /opt/iptv/LOGS/${1}.log 2>&1 &

# create master playlist file
#echo -e "${master_playlist}" > ${target}/playlist.m3u8

#echo "Done - encoded HLS is at ${target}/"

