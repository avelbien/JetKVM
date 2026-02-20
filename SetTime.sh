#!/bin/sh

# задержка чтобы сеть поднялась
sleep 30

# повторять, пока есть интернет
while ! ping -c1 -W1 google.com >/dev/null 2>&1; do
  sleep 5
done

# получить заголовок Date из HTTP ответа
wget -q -O- -S --spider http://www.google.com 2>&1 | \
grep -w Date: | head -n1 | \
cut -d':' -f2- | sed -E 's/^[ \t]*//' | \
awk '
{
  day = $2;
  month = $3;
  year = $4;
  time = $5;

  gsub("Jan","01",month);
  gsub("Feb","02",month);
  gsub("Mar","03",month);
  gsub("Apr","04",month);
  gsub("May","05",month);
  gsub("Jun","06",month);
  gsub("Jul","07",month);
  gsub("Aug","08",month);
  gsub("Sep","09",month);
  gsub("Oct","10",month);
  gsub("Nov","11",month);
  gsub("Dec","12",month);

  printf("%s-%s-%s %s\n", year, month, day, time);
}
' | xargs -I{} date -s "{}"

# обновить аппаратные часы (если есть)
hwclock -w 2>/dev/null