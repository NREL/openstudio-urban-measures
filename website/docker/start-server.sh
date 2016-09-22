#!/bin/bash
sleep 10
cd /srv && bundle exec rake db:seed
cd /srv && bundle exec rake db:mongoid:create_indexes
/opt/nginx/sbin/nginx
