[![License](license-apache-2.svg)](https://github.com/AVGTechnologies/lab_manager/blob/master/LICENSE)

Lab Manager
===========

Web Application providing uniform API to several cloud providers (Vsphere, Azure, ovirt, ...)

Endpoints
---------

```
GET  /computes
POST /computes
GET  /computes/:id
DELETE /computes/:id
PUT /computes/:id/power_on
PUT /computes/:id/power_off
PUT /computes/:id/reboot

GET  /computes/:id/snapshots
POST /computes/:id/snapshots
GET  /computes/:id/snapshots/:id
POST /computes/:id/snapshots/:id/revert
```

Status
------

**This app is in develomplent - Not production ready**

Development
-----------

##setup

     #create/modify config/database.yml
     #create/modify config/lab_manager.yml
     rake db:setup


##run app

     rerun rackup

(you can install reran globally by: `rvm @global do gem install rerun`)


##example usage
```
#create & poweron virtual machine (compute unit)
curl -i -H 'Content-Type: application/json' --data '{"provider_name":"v_sphere","image":"TA_8x64"}' localhost:21000/computes/
#it returns id of the created compute

#destroy compute with id 1
curl -i -X DELETE localhost:21000/computes/9

```
