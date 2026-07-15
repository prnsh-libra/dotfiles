#!/usr/bin/env sh

cpu_usage() {
  awk -v prev_idle="$1" -v prev_total="$2" '
    /^cpu / {
      idle=$5; total=0; for (i=2;i<=NF;i++) total+=$i;
      d_idle=idle-prev_idle; d_total=total-prev_total;
      if (d_total > 0) printf("%.0f", (1 - d_idle/d_total) * 100);
      else printf("0");
    }
  ' /proc/stat
}

read cpu_idle cpu_total <<EOFSTAT
$(awk '/^cpu /{print $5, ($2+$3+$4+$5+$6+$7+$8+$9+$10+$11)}' /proc/stat)
EOFSTAT

sleep 0.2

cpu=$(cpu_usage "$cpu_idle" "$cpu_total")

mem=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {if (t>0) printf("%.0f", (t-a)/t*100); else print "0"}' /proc/meminfo)

if [ -r /proc/self/mounts ]; then
  fs=$(awk '$2=="/" {print $3" "$4}' /proc/self/mounts)
  used=$(df -P / | awk 'NR==2 {print $5}' | tr -d '%')
else
  used=0
fi

printf "  %%{T3}%%{T-} %s%%  %%{T3}%%{T-} %s%%  %%{T3}󰋊%%{T-} %s%%  " "$cpu" "$mem" "$used"
