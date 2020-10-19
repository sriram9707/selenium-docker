#!/usr/bin/env bash

# set -e: exit asap if a command exits with a non-zero status
set -e

# Make it portable
[ -z "${VIDEO_BASE_PATH}" ] && export \
    VIDEO_BASE_PATH="${VIDEOS_DIR}/${VIDEO_FILE_NAME}"
[ -z "${FFMPEG_FRAME_SIZE}" ] && export \
    FFMPEG_FRAME_SIZE="${SCREEN_WIDTH}x${SCREEN_HEIGHT}"

# Remove the video file if exists
# Added a non-sudo conditional so this works on non-sudo environments like K8s
if [ "${WE_HAVE_SUDO_ACCESS}" == "true" ]; then
  sudo rm -f "${VIDEO_BASE_PATH}"*
else
  rm -f "${VIDEO_BASE_PATH}"*
fi

# record testing video using password file
# using sudo due to http://stackoverflow.com/questions/23544282/
# ffmpeg
#  -an            no audio
#  -v loglevel    set logging level, e.g. quiet
#  -t duration    Stop writing the output after its duration reaches duration
#                 duration may be a number in seconds, or in
#                 "hh:mm:ss[.xxx]" form.
#  -f   x11grab   force format
#  -y             overwrite output files
#  -i             display and pos
#  https://www.ffmpeg.org/ffmpeg-codecs.html

export tmp_video_path="${VIDEOS_DIR}/${VIDEO_FILE_NAME}.${VIDEO_TMP_FILE_EXTENSION}"
export final_video_path="${VIDEOS_DIR}/${VIDEO_FILE_NAME}.${VIDEO_FILE_EXTENSION}"

# Fix perms to be able to start ffmpeg without sudo
# Added a non-sudo conditional so this works on non-sudo environments like K8s
if [ "${WE_HAVE_SUDO_ACCESS}" == "true" ]; then
  TMP_CUR_USER=$(whoami)
  TMP_CUR_GROUP=$(id -g)
  sudo touch "${tmp_video_path}"
  sudo chown ${TMP_CUR_USER}:${TMP_CUR_GROUP} "${tmp_video_path}"
  sudo chmod 666 "${tmp_video_path}"
else
  touch "${tmp_video_path}"
fi

# ffmpeg
if  [ "${AUDIO}" == "true" ]; then
  # Start the pulseaudio server
  pulseaudio -D --exit-idle-time=-1

  # Load the virtual sink and set it as default
  pacmd load-module module-virtual-sink sink_name=v1
  pacmd set-default-sink v1

  # set the monitor of v1 sink to be the default source
  pacmd set-default-source v1.monitor

  ffmpeg \
    -s "${FFMPEG_FRAME_SIZE}" \
    -draw_mouse ${FFMPEG_DRAW_MOUSE} \
    -r ${FFMPEG_FRAME_RATE} \
    -f "x11grab" \
    -i "${DISPLAY}.0" \
    -f "pulse" \
    -i "default" \
    ${FFMPEG_CODEC_VA_ARGS} \
    -y "${tmp_video_path}" 2>&1 &
else
  ffmpeg \
    -s ${FFMPEG_FRAME_SIZE} \
    -draw_mouse ${FFMPEG_DRAW_MOUSE} \
    -r ${FFMPEG_FRAME_RATE} \
    -f "x11grab" \
    -i "${DISPLAY}.0" \
    ${FFMPEG_CODEC_ARGS} \
    -y -an "${tmp_video_path}" 2>&1 &
fi

VID_TOOL_PID=$!

# Exit all child processes properly
function shutdown {
  log "Trapped SIGTERM or SIGINT so shutting down ffmpeg gracefully..."
  log "Will kill VID_TOOL_PID=${VID_TOOL_PID} ..."

  local __1st_sig="${VIDEO_STOP_1st_sig_TYPE}"
  local __2nd_sig="${VIDEO_STOP_2nd_sig_TYPE}"
  local __3rd_sig="${VIDEO_STOP_3rd_sig_TYPE}"

  sleep ${VIDEO_BEFORE_STOP_SLEEP_SECS}
  kill -${__1st_sig} ${VID_TOOL_PID} || log "Tried to kill -${__1st_sig} VID_TOOL_PID=${VID_TOOL_PID}"
  # killall -${__1st_sig} ffmpeg || log "Tried to killall -${__1st_sig} ffmpeg"

  local __secs=${VIDEO_WAIT_VID_TOOL_PID_1st_sig_UP_TO_SECS}
  log "Waiting up to ${__secs} for VID_TOOL_PID=${VID_TOOL_PID} to end with ${__1st_sig}..."
  if timeout --foreground "${__secs}" \
        wait_pid ${VID_TOOL_PID}; then
    log "wait_pid successfully managed to ${__1st_sig}:VID_TOOL_PID=${VID_TOOL_PID} within less than ${__secs}"
  else
    log "Failed VID_TOOL_PID=${VID_TOOL_PID} took longer than ${__secs} ! will try to kill it again..."

    local __secs=${VIDEO_WAIT_VID_TOOL_PID_2nd_sig_UP_TO_SECS}
    kill -${__2nd_sig} ${VID_TOOL_PID} || log "Tried tond) on kill -${__2nd_sig} VID_TOOL_PID=${VID_TOOL_PID}"
    log "Waiting (again) up to ${__secs} for VID_TOOL_PID=${VID_TOOL_PID} to end with ${__2nd_sig}..."
    if timeout --foreground "${__secs}" \
          wait_pid ${VID_TOOL_PID}; then
      log "wait_pid (3rd) successfully managed to ${__2nd_sig}:VID_TOOL_PID=${VID_TOOL_PID} within less than ${__secs}"
    else
      log "Failed (3rd) VID_TOOL_PID=${VID_TOOL_PID} took longer than ${__secs} ! will try to kill it again..."

      local __secs=${VIDEO_WAIT_VID_TOOL_PID_3rd_sig_UP_TO_SECS}
      kill -${__3rd_sig} ${VID_TOOL_PID} || log "Tried toth) on kill -${__3rd_sig} VID_TOOL_PID=${VID_TOOL_PID}"
      if timeout --foreground "${__secs}" \
            wait_pid ${VID_TOOL_PID}; then
        log "wait_pid (4th) successfully managed to ${__3rd_sig}:VID_TOOL_PID=${VID_TOOL_PID} within less than ${__secs}"
      else
        log "Failed (4th) VID_TOOL_PID=${VID_TOOL_PID} took longer than ${__secs} ! will try to kill it again..."
        kill -9 ${VID_TOOL_PID} || log "Tried toth) on kill -9 VID_TOOL_PID=${VID_TOOL_PID}"
      fi
    fi
  fi
  log "Will try to fix the videos..."
  sleep ${VIDEO_AFTER_STOP_SLEEP_SECS}
  fix_videos.sh || log "Failed to fix_videos.sh"
  log "ffmpeg shutdown complete."
  exit 0
}

# Wait for the file to exists
log "Waiting for file ${VIDEO_BASE_PATH}* to be created..."
while ! ls -l "${VIDEO_BASE_PATH}"* >/dev/null 2>&1; do sleep 0.1; done

# Now wait for video recording to start or fail
timeout --foreground ${WAIT_TIMEOUT} wait-video-rec.sh

# Run function shutdown() when this process receives a killing signal
trap shutdown SIGTERM SIGINT SIGKILL

# tells bash to wait until child processes have exited
wait