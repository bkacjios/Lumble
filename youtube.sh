#!/bin/bash
youtube-dl -q -f 251 $1 -o - | ffmpeg -hide_banner -loglevel quiet -re -i - -f f32le -acodec pcm_f32le -ac 2 -b:a 45k udp://127.0.0.1:1337?pkt_size=7680 &
echo $! > youtube.pid