#!/usr/bin/env coffee
require 'require-yaml'
require 'unorm'
xregexp = require('xregexp').XRegExp

netatmo = require('netatmo')

secret = require './secret.yml'
config = require './config.yml'

console.log config
root = exports ? this

ten_min_sec = 600
one_hour_sec = 3600
argv = require('minimist')(process.argv.slice(2))

get_thermostat = false
if argv.t
  get_thermostat = true

norm = (string) ->
  string.normalize("NFKD").replace(xregexp("\\p{M}", "g"), "").replace(new RegExp(" ", 'g'),"-")

auth = {
  "client_id": secret.netatmo.client_id,
  "client_secret": secret.netatmo.client_secret,
  "username": secret.netatmo.username,
  "password": secret.netatmo.password,
}

librato = require('librato-metrics').createClient({
  email: secret.librato.email,
  token: secret.librato.token,
})

data = {gauges: []}

api = new netatmo(auth);

all_calbacks_done = 0

getDevicelist = (err, devices, modules) ->
#  console.log devices
#  console.log modules
  device_name = {}
  device_thermostat = {}
  device_end_time = {}
  if devices.length > 0
   console.log '####################### DEVICES #######################'
   for device in devices
    console.log '----------------------- Device '+device.station_name+'('+device._id+') -----------------------'
    device_name[device._id]=norm(device.station_name)
    device_end_time[device._id]=device.last_status_store
    end_time = device.last_status_store
    time_to_retrieve = 2*ten_min_sec
    if device.type == 'NAMain'
      console.log "Weather Station detected"
      device_thermostat[device._id] = false
    else
      console.log "Thermostat detected"
      time_to_retrieve = 2*one_hour_sec
      device_thermostat[device._id] = true
      device.data_type = ['Temperature', 'Sp_Temperature', 'BoilerOn', 'BoilerOff']
 
    if device.data_type != []
      options = { 
        device_id: device._id,
        scale: 'max',
        type: device.data_type,
        optimize: false,
        date_begin: end_time - time_to_retrieve,
        date_end: end_time
      }
      #console.log options
      console.log '####################### Measure #######################'
      all_calbacks_done += 1
      console.log '!!!!!!!!!!!!!!!!!!!!!!! Nb of callbacks: '+all_calbacks_done
      if typeof device.module_name == "undefined"
        device.module_name = device.station_name
      api.getMeasure options, getMeasure_maker(device_name[device._id],norm(device.module_name), device.data_type)
    console.log '----------------------- End Device '+device.station_name+' -----------------------'
    console.log '####################### END DEVICES #######################'

  if modules.length > 0
    console.log '####################### MODULES #######################'
    for module in modules
      console.log('----------------------- Module '+module.module_name+'(from device '+device_name[module.main_device]+') -----------------------')
      time_to_retrieve = 2*ten_min_sec
      if device_thermostat[module.main_device]
        console.log "Thermostat module detected"
        module.data_type = ['Temperature', 'Sp_Temperature', 'BoilerOn', 'BoilerOff']
        time_to_retrieve = 2*one_hour_sec
      else
        console.log "Weather module Station detected"
      if module.data_type != []
        options = { 
          device_id: module.main_device,
          module_id: module._id
          scale: 'max',
          type: module.data_type,
          optimize: false,
          date_begin: device_end_time[module.main_device]  - time_to_retrieve,
          date_end: device_end_time[module.main_device]
        }
        #console.log options
        console.log '####################### Measure #######################'
        all_calbacks_done += 1
        console.log '!!!!!!!!!!!!!!!!!!!!!!! Nb of callbacks: '+all_calbacks_done
        api.getMeasure options, getMeasure_maker(device_name[module.main_device],norm(module.module_name), module.data_type)
      console.log '----------------------- End Module '+module.module_name+'(from device '+device_name[module.main_device]+') -----------------------'
    console.log '####################### END MODULES #######################'

getMeasure_maker = (device_name, module_name, data_type) ->
  getMeasure = (err, measure) ->
    all_calbacks_done -= 1
    console.log '!!!!!!!!!!!!!!!!!!!!!!! Nb of callbacks: '+all_calbacks_done
    console.log '----------------------- Measure result for '+device_name+'.'+module_name+'['+data_type+'] -----------------------'
    #console.log(measure)
    if measure != []
      for own epoch, measures of measure
        #console.log epoch
        for measurement, i in measures
          data.gauges.push { name:'netatmo.'+device_name+'.'+module_name+'.'+data_type[i] , value: measurement, measure_time: epoch }
      #console.log data
    console.log '----------------------- End Measure result for '+device_name+'.'+module_name+' -----------------------'
    if all_calbacks_done == 0
      console.log '!!!!!!!!!!!!!!!!!!!!!!! All Callbacks done, processing datas !!!!!!!!!!!!!!!!!!!!!!!'
      process_datas()

process_datas = () ->
  console.log '####################### Processing datas #######################'
  console.log data
  librato.post('/metrics', data, (err, response) -> 
    if err 
      console.error "error detected"
      console.error err
      if err.errors != undefined
        if err.errors.params != undefined
          console.error err.errors.params
          if err.errors.params.measure_time != undefined
            console.error err.errors.params.measure_time
    if response != undefined
      console.log(response)
    else
      console.log "post to librato OK"
  )
  console.log '####################### End Processing datas #######################'

date = new Date().toISOString().replace(/T/, ' ').replace(/\..+/, '')
console.log '/////////////////////// Starting process at '+date+'\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'          
data = {gauges: []}
options = { app_type: 'app_station'}
api.getDevicelist(options, getDevicelist)
if get_thermostat
  console.log 'processing thermostat'
  options = { app_type: 'app_thermostat' }
  api.getDevicelist(options, getDevicelist)
date = new Date().toISOString().replace(/T/, ' ').replace(/\..+/, '')
console.log '/////////////////////// End process at '+date+'\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
