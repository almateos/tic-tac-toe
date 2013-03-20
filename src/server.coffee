express = require 'express'
#app     = module.exports =  express()
app    = require('express')()
http = require('http')
url = require('url')
server = http.createServer(app)
io      = require('socket.io').listen(server)
crypto = require("crypto")
clients = {}
#pl = 1
pa = 1

users = {}

path = require('path')

config = {
  api:
    host: 'api.almateos.dev'
}

# TODO: 1. move big code below in a file
# TODO: 2. move big-server as npm module
#BIG = require('assets/js/big-server.js')

class BIG

  methods = ['GET','POST', 'PUT', 'DELETE']

  @authKeys: {
    api_key: '39802830831bed188884e193d8465226'
    api_secret: 'e720dfe014c0107e3f080b0880997bca'
  }

  @api: (method, endpoint, params, callback) ->
    # check method validity
    requestType = method.trim().toUpperCase()
    callback({code: 405, error: "Bad method type"}, null) unless methods.indexOf(requestType) > -1

    # automatically add authentication params to url
    #endpoint = if endpoint.match(/\?/) then endpoint + '&' else endpoint + '?') + url.format({query: authKeys})
    getParams = this.authKeys
    if(method == "GET")
      for k, v of params
        getParams.k = v
    endpoint += url.format({query: getParams})

    body = if (method == "GET") then '' else JSON.stringify(params);
    options =
        hostname: config.api.host
        port: 80
        path: endpoint
        method: method
        headers:
          'Content-Type': 'application/json',
          'Content-Length': body.length
        #auth: authKeys.api_key + ':' + authKeys.api_secret

    req = http.request options, (res) ->
      #console.log('STATUS: ' + res.statusCode)
      #console.log('HEADERS: ' + JSON.stringify(res.headers))
      res.setEncoding('utf8')
      res.on 'data', (chunk) ->
        console.log 'daahhhh:', chunk
        #console.log('BODY: ' + chunk)
        #TODO: check if response content-type is in json ?
        callback(null, {data: JSON.parse(chunk), body: chunk, code: res.statusCode, headers: res.headers })

    req.on 'error', (e) ->
      callback({code: e.statusCode, error: e.message, raw: e})
      #console.log('problem with request: ' + e.message)

    if(method != "GET")
      req.write(body)
    #req.write('data\n')
    req.end()

#BIG.api 'get', '/players', {}

#haml = require 'hamljs'
#cons = require 'consolidate'

app.configure(() ->
  app.set 'port', process.env.PORT || 3000

  rootPath = path.join __dirname , '../'
  app.set 'views', rootPath
  app.engine('html', require('ejs').renderFile)

  app.set("view options", {layout: false})
  app.use express.logger()

  app.use express.bodyParser()
  app.use express.cookieParser('//Secr8t...Sh4ll+R7M1ND S3cr3t@@')
  app.use express.cookieSession()

  app.use app.router
  app.use express.methodOverride()
  app.use express.static(rootPath)
)

server.listen app.get 'port'

parties = []
grids   = []
waiting = false

###### winRule
rules = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8], # horrizontal
  [0, 3, 6], [1, 4, 7], [2, 5, 8], #vertical
  [0, 4, 8], [2, 4, 6] #diagonal
]

team = [false, true]

emit = (clientName, args...) ->
  clients[clientName].emit.apply clients[clientName], args if(clients[clientName] != undefined)

io.sockets.on 'connection', (socket) ->

  socket.on 'disconnect', () ->

    if parties[socket.party] != undefined
      party   = parties[socket.party]
      ennemy = if party[0] != socket.pl then party[0] else party[1]
      delete parties[socket.party]
      BIG.api 'post', '/challenges', { winners: [ennemy], loosers: [socket.pl], cause: 'disconnection' }, (err, res) ->
        emit(ennemy, 'msg', 'Your adversary just disconnected.')
        emit(ennemy, 'end', 'win')
        console.log('logged out:', err, res)

    BIG.api 'post', '/players', { id: socket.pl, online: 0 }, (err, res) ->
      console.log('logged out:', err, res)
    delete clients[socket.pl]
      
  socket.on 'register', (pl) ->
    console.log('register:', pl)
    console.log('waiting:', waiting)
    console.log('parties:', parties)
    console.log('clients:', clients)
    console.log('users:', users)
    #clients[name] = socket
    if pl != undefined && clients[pl] == undefined && users[pl] != undefined
      clients[pl] = socket
      socket.pl = pl

      BIG.api 'post', '/players', { id: pl, online:1 }, (err, res) ->
        console.log('logged in:', err, res)
        emit(pl, 'registered', pl)

  ###
    #  parties.push [name] if(waiting)
      if waiting && waiting != pl
        console.log(2)
        parties[pa] = [waiting, pl]
        grids[pa] = []

        clients[waiting].index = 0
        clients[waiting].team = team[0]
        clients[waiting].party = pa
        emit(waiting, 'team', team[0])

        clients[pl].index = 1
        clients[pl].team = team[1]
        clients[pl].party = pa
        emit(pl, 'team', team[1])

        waiting = false
        pa++
      else
        waiting = pl
      #pl++
  ###

  socket.on 'move', (gid) ->
    grid = grids[socket.party]
    grid[gid] = socket.team
    party   = parties[socket.party]
    ennemy = if party[0] != socket.pl then party[0] else party[1]

    emit(ennemy, 'move', gid)
    for i in [0...rules.length]
      res = true
      for j in [0...rules[i].length]
        res = false if(grid[rules[i][j]] != socket.team)
      if res == true
        BIG.api 'post', '/challenges', { winners: [ennemy], loosers: [socket.pl], cause: 'normal' }, (err, res) ->
          emit(socket.pl, 'end', true)
          emit(ennemy, 'end', false)
          delete parties[socket.party]


# Express "actions"
isLoggedIn = (req) ->
  res = req.session.token != undefined && users[req.session.user] != undefined && users[req.session.user].token == req.session.token
  req.session = {} if(!res)
  return res

getSessionHash = (login, password) ->
  sha256 = crypto.createHash('sha256')
  return sha256.update(login + 's@lt//123' + password, "utf8").digest("base64")

app.get '/start-game/p1/:p1/p2/:p2',  (req, res) ->
  p1 = req.params.p1
  p2 = req.params.p2
  console.log p1, p2

  if(clients[p1] != undefined && clients[p2] != undefined)
    parties[pa] = [p1, p2]
    grids[pa] = []

    clients[p1].index = 0
    clients[p1].team = team[0]
    clients[p1].party = pa
    emit(p1, 'team', team[0])

    clients[p2].index = 1
    clients[p2].team = team[1]
    clients[p2].party = pa
    emit(p2, 'team', team[1])
    code = 200
    ret = 'ok'
  else
    code = 500
    ret = 'ko'

  res.writeHead(200, { 'Content-Type': 'application/json' })
  res.write(JSON.stringify(ret))
  res.end()

app.get '/', (req, res) ->
  if(isLoggedIn(req))
    user = users[req.session.user]
    console.log('users:', users)
    res.render('index.html', {locals: { player_id: req.session.user, player_token: user.player_token, api_key: BIG.authKeys.api_key}})
  else
    res.redirect('/login')

app.get '/login', (req, res) ->
  if(isLoggedIn(req))
    res.redirect('/')
  else
    res.render('login.html')

app.get '/logout', (req, res) ->
    req.session = null
    res.redirect '/'

app.get '/register', (req, res) ->
  if(isLoggedIn(req))
    res.redirect('/')
  else
    res.render('register.html')

login = (req, res, username, hash) ->
    req.session.token = hash
    req.session.user = username

    BIG.api 'post', '/players', { id: username }, (err, res2) ->
      users[username].player_token = res2.data.response.token
      console.log('logged in:', err, res2)
      res.redirect('/')

app.post '/register', (req, res) ->
  post = req.body
  error = false
  if (!isLoggedIn(req))
    if (post.username != undefined && post.username.length > 0 &&
    post.password != undefined && post.password.length > 0 &&
    post.password2 != undefined && post.password2.length > 0)
      if post.password == post.password2
        if(users[post.username] == undefined)
          hash = getSessionHash(post.username, post.password)
          users[post.username] = {
            password: post.password
            token: hash
          }
          login(req, res, post.username, hash)
          #password = sha256.update(post.password, "utf8").digest("base64")
        else error = 'Login already exists'
      else error = 'Passwords don\'t match'
    else error = 'Missing params'
    if(error) then res.render('register.html', {error: error})


app.post '/login', (req, res) ->
  post = req.body
  user = users[post.username]
  #password = sha256.update(post.password, "utf8").digest("base64")
  password = post.password
  if (user != undefined  &&  password == user.password)
    hash = getSessionHash(post.username, post.password)
    login(req, res, post.username, hash)
  else
    error = 'Bad user/pass'
    res.render('login.html', {error: error})
