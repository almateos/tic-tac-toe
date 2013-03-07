Compile coffee

``coffee --compile --output build src``

Install node module 

``npm install``

Start server

``node build/server.js``

Browse website at http://localhost:3000

Note 1: *You can change port in src/server.coffee*

Note 2: *If you change port or want to host elsewhere than localhost, you have to
change port and/or url in src/client.coffee*

