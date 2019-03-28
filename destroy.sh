#!/bin/sh

minishift delete -f
rm ~/.minishift/config/config.json
rm ~/.minishift/config/minishift.json
