express = require 'express'
#app     = module.exports =  express()
app    = require('express')()
server = require('http').createServer(app)
io      = require('socket.io').listen(server)
clients = {}
pl = 1
pa = 1

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
  app.use express.cookieParser()
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
      console.log(socket.id)
      
  socket.on 'register', () ->
    #console.log('register:', i)
    #clients[name] = socket
    clients[pl] = socket
    socket.pl = pl
    emit(pl, 'registered', pl)
  #  parties.push [name] if(waiting)
    if waiting
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
    pl++

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

app.get '/', (req, res) ->
  res.render('index.html')
