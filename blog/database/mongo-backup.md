# mongodb backup

```bash
mongorestore --host localhost:27017 -u root -p 123456 --authenticationDatabase=admin --dir=./dump

mongodump --host x.x.x.x:27017 -u root -p passw --authenticationDatabase=admin --db=testdb -o /data/dump_testdb
```