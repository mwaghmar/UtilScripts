#!/bin/bash

curl -XGET 'http://localhost:9200/services/doctor/_search?pretty=true' -d '
{
    query : {
        matchAll : {}
    }
}'
