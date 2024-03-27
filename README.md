# ntc-script
ntc-script is a collection of script files used in devops.  


## Sample script migrate data mongodb from 4.2 --> 4.4 --> 5.0
```bash
# Giả định tất cả data đã mongodump trong thư mục /home/nghiatc/lab/labMongo/db/dump
# và đã cài đặt Docker.
chmod +x mongo_upgrade.sh
./mongo_upgrade.sh
```

