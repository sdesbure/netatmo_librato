# netatmo_librato

A node.js server which will grab information from netatmo and send them to librato

## How to use

You have two choices :
 * use the daemon script (via the debian helper for example) named `netatmo_librato_daemon.js`
 * use via crontab every 10 min the one shot script (`netatmo_librato.coffee`)
 
## Configuration

nodejs and coffeescript (for the one shot script) are required. Other dependencies are bundled
`secret.yml` must provide the credentials to netatmo and librato (an example is given).
`config.yml` is only needed for the daemon in order to make it work (the default value should be sufficient for everybody).

You'll need a netatmo account, a netatmo application created and a librato account

For the one shot script, `-t`flag ask the script to retrieve also the value from a thermostat. It should be done every hour. For me, it seems that thermostat is updated just after half the hour.
```
0,10,20,30,50 * * * * /opt/nodejes/netatmo_librato/netatmo_librato.coffee > /var/log.netatmo_librato.log
40 * * * * /opt/nodejes/netatmo_librato/netatmo_librato.coffee -t > /var/log.netatmo_librato.log
```

## License

Licensed under the MIT license.
