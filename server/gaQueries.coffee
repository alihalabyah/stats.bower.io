# vendor
Promise = require 'bluebird'
_find = require 'lodash-node/modern/collections/find' # to be replaced w/ array.prototype.find w/ node --harmony

# custom
config = require "./config"
geo = require "./geo"
gh = require './github'

# ==========

###
# generic GA util
###

util =
  removeSlash: (input) -> input.replace /\//g, '' # remove leading & trailing /

###
# GA query def
###

queries = {}

queries.users =
  queryObjs: [
    {
      'ids': 'ga:' + config.ga.profile
      'start-date': '2014-03-15'
      'end-date': 'yesterday'
      'metrics': 'ga:users'
      'dimensions': 'ga:userType,ga:date'
    }
  ]
  transform: (data) ->
    result = data[0].rows
    result.forEach (d) ->
      d[0] = if d[0].indexOf('New') != -1 then 'N' else 'E'
      d[2] = +d[2]
      return
    result

queries.cmds =
  queryObjs: [
    {
      'ids': 'ga:' + config.ga.profile
      'start-date': '13daysAgo'
      'end-date': 'yesterday'
      'metrics': 'ga:users,ga:pageviews'
      'dimensions': 'ga:pagePathLevel1,ga:nthWeek'
    }
  ]
  transform: (data) ->
    cmdIcons = # define font awesome icons
      Install: 'download'
      Installed: null
      Uninstall: 'trash-o'
      Uninstalled: null
      Register: 'pencil'
      Registered: null
      Unregister: 'eraser'
      Info: 'info'
      Search: 'search'
    cmds = Object.keys cmdIcons
    # set order for display
    order = {}
    cmds.forEach (cmd, i) -> order[cmd] = i; return

    _transform = (d) ->
      cmdName = util.removeSlash d[0]
      cmdName = cmdName.charAt(0).toUpperCase() + cmdName.slice 1 # Cap Case

      cmd: cmdName
      order: order[cmdName]
      icon: cmdIcons[cmdName]
      metrics: [
        {metric: 'users', order: 1, current: +d[2]} # ga:users
        {metric: 'uses', order: 2, current: +d[3]} # ga:pageviews
      ]

    current = data[0].rows.filter((d) -> +d[1] is 1).map _transform # current week
    prior = data[0].rows.filter((d) -> +d[1] is 0).map _transform # previous week

    # remove garbage data from GA e.g. (not set), FakeXMLHttpRequest, Pretender, Route-recognizer...
    garbageFilter = (cmdName) -> cmds.indexOf(cmdName) isnt -1
    edFilter = (cmdName) -> cmdName.indexOf("ed") is -1 # no "-ed"
    result = current.filter (cmdObj) ->
      # console.log "1 = #{garbageFilter cmdObj.cmd}, 2 = #{edFilter cmdObj.cmd}"
      garbageFilter(cmdObj.cmd) and edFilter(cmdObj.cmd)

    getValue = (cmdName, period, ed, valueType) ->
      ed = if ed then 'ed' else ''
      i = if valueType is 'users' then 0 else 1 # ga:users : ga:pageviews
      try # catch edge case in case new cmd tracked and no prior history
        _find(period, (d) -> d.cmd is cmdName + ed).metrics[i].current
      catch err
        console.error err; 0

    result.forEach (cmd) ->
      # cmd with pkgs count, i.e. suffixed w/ 'ed'
      if ["Install", "Uninstall", "Register", "Unregister"].indexOf(cmd.cmd) isnt -1
        cmd.metrics.push {
          metric: 'pkgs', order: 3
          current: getValue cmd.cmd, current, true, 'pkgs'
        }

      cmd.metrics.forEach (metric) ->
        metric.prior = getValue cmd.cmd, prior, (if metric.metric is 'pkgs' then true else false), metric.metric
        metric.delta = metric.current / metric.prior - 1
        return

      return

    result

queries.pkgs =
  # 'package' is a reserved word in JS
  # only want to pull pkgs w/ >= 5 installs, which is around the 3500th pkg sorted by installs
  queryObjs: [
    { # current week
      'ids': 'ga:' + config.ga.profile
      'start-date': '7daysAgo'
      'end-date': 'yesterday'
      'metrics': 'ga:users,ga:pageviews'
      'dimensions': 'ga:pagePathLevel2'
      'filters': 'ga:pagePathLevel1=@installed' # =@ contains substring, don't use url encoding '%3D@'
      'sort': '-ga:pageviews'
      'max-results': 3500
    }
    { # prior week
      'ids': 'ga:' + config.ga.profile
      'start-date': '14daysAgo'
      'end-date': '8daysAgo'
      'metrics': 'ga:users,ga:pageviews'
      'dimensions': 'ga:pagePathLevel2'
      'filters': 'ga:pagePathLevel1=@installed'
      'sort': '-ga:pageviews'
      'max-results': 3500
    }
  ]
  transform: (data) ->
    console.log data[0].rows[1]
    current = data[0].rows[..29] # TODO: ranking range as arg
    prior = data[1].rows[..99] # need more rows in case ranking diff b/t current / prior is too large

    _transform = (d, i) ->
      d[0] = util.removeSlash d[0]
      d[1] = +d[1]; d[2] = +d[2]
      d.push i + 1 # rank
      return
    current.forEach _transform
    prior.forEach _transform

    result = current.map (d) ->
      bName: d[0]
      bRank: current: d[3]
      bUsers: current: d[1] # ga:users
      bInstalls: current: d[2] # ga:pageviews

    ghPromises = []
    result.forEach (pkg) ->
      priorPkg = _find prior, (d) -> d[0] is pkg.bName
      if priorPkg?
        pkg.bRank.prior = priorPkg[3]
        pkg.bUsers.prior = priorPkg[1]
        pkg.bInstalls.prior = priorPkg[2]
      else
        error = new Error "[ERROR] no prior period data for pkg #{ pkg.bName }"
        console.error error
      ghPromises.push gh.appendData pkg
      return

    Promise.all(ghPromises).then -> result

queries.geo =
  queryObjs: [
    { # monthly active users
      'ids': 'ga:' + config.ga.profile
      'start-date': '30daysAgo'
      'end-date': 'yesterday'
      'metrics': 'ga:users'
      'dimensions': 'ga:country'
      'sort': '-ga:users'
    }
  ]
  transform: (data) ->
    current = data[0].rows
    geoPromises = []

    # remove (not set) country & country w/ just 1 user
    current = current.filter (country) ->
      country[0] != "(not set)" and +country[1] > 1

    result = current.map (d) ->
      name: d[0]
      isoCode: geo.getCode d[0] # get ISO 3166-1 alpha-3 code
      users: +d[1]

    result.forEach (country) ->
      geoPromise = geo.getPop(country.isoCode).then (pop) ->
        country.density = Math.ceil(country.users / pop * 1000000)
        return
      # get population from world bank api then calc bower user density per 1m pop
      geoPromises.push geoPromise
      return

    Promise.all geoPromises
      .call 'sort', (a, b) -> b.density - a.density
      .then -> result

module.exports = queries