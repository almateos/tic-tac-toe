express = require 'express'
#app     = module.exports =  express()
app    = require('express')()
server = require('http').createServer(app)
io      = require('socket.io').listen(server)
crypto = require("crypto")
clients = {}
#pl = 1
pa = 1

users = {}

path = require('path')

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

io.sockets.on 'connection', (socket) ->
  emit = (clientName, args...) ->
    clients[clientName].emit.apply clients[clientName], args if(clients[clientName] != undefined)

    socket.on 'disconnect', () ->
      delete clients[socket.pl]
      console.log('delete' + socket.pl)
      
  socket.on 'register', (pl) ->
    console.log('register:', pl)
    console.log('waiting:', waiting)
    console.log('parties:', parties)
    console.log('clients:', clients)
    console.log('users:', users)
    #clients[name] = socket
    if pl != undefined && clients[pl] == undefined && users[pl] != undefined
      console.log(1)
      clients[pl] = socket
      socket.pl = pl
      emit(pl, 'registered', pl)
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

  socket.on 'move', (gid) ->
    grid = grids[socket.party]
    grid[gid] = socket.team
    partyId = socket.party
    party   = parties[partyId]
    ennemy = if party[0] != socket.pl then party[0] else party[1]

    emit(ennemy, 'move', gid)
    for i in [0...rules.length]
      res = true
      for j in [0...rules[i].length]
        res = false if(grid[rules[i][j]] != socket.team)
      if res == true
        emit(socket.pl, 'end', 'win')
        emit(ennemy, 'end', 'lose')


# Express "actions"
isLoggedIn = (req) ->
  res = req.session.token != undefined && users[req.session.user] != undefined && users[req.session.user].token == req.session.token
  req.session = {} if(!res)
  return res

getSessionHash = (login, password) ->
  sha256 = crypto.createHash('sha256')
  return sha256.update(login + 's@lt//123' + password, "utf8").digest("base64")

app.get '/', (req, res) ->
  if(isLoggedIn(req))
    res.render('index.html', {locals: { login: req.session.user}})
  else
    res.redirect('/login')

app.get '/login', (req, res) ->
  if(isLoggedIn(req))
    res.redirect('/')
  else
    res.render('login.html')

app.get '/register', (req, res) ->
  if(isLoggedIn(req))
    res.redirect('/')
  else
    res.render('register.html')


app.post '/register', (req, res) ->
  post = req.body
  if (post.login != undefined && post.login.length > 0 &&
  post.password != undefined && post.password.length > 0 &&
  post.password2 != undefined && post.password2.length > 0)
    if post.password == post.password2
      if(users[post.login] == undefined)
        hash = getSessionHash(post.login, post.password)
        password = post.password
        #password = sha256.update(post.password, "utf8").digest("base64")
        req.session.token = hash
        req.session.user = post.login
        users[post.login] = {
          password: password
          token: hash
        }
        res.redirect('/')
      else
        res.send('Login already exists')
    else
      res.send('Passwords don\'t match')
  else
    res.send('Missing params')

app.post '/login', (req, res) ->
  post = req.body
  user = users[post.login]
  #password = sha256.update(post.password, "utf8").digest("base64")
  password = post.password
  if (user != undefined  &&  password == user.password)
    req.session.token = hash
    req.session.user = post.login
    res.redirect('/')
  else
    res.send('Bad user/pass')
