var jsonServer = require('json-server')
var _us = require('underscore')
var fs = require('fs')

// Returns an Express server
var server = jsonServer.create()

// Allow CORS with localhost
server.all("*", function(req, res, next) {
  res.header("Access-Control-Allow-Origin", "*");
  return next();
});

// Add custom routes before JSON Server router
var nextId = 2
var db =
    [ { name: 'Dataray'
      , bandVotes: 7
      , albumVotes: 3
      , id: 0
      }
    , { name: 'Bob and the Bobs'
      , bandVotes: 8 
      , albumVotes: 0
      , id: 1
      }
    ];

server.get('/candidates', function (req, res) {
  var entries = _us.uniq(db.entries)
  res.jsonp(db)
})

server.post('/candidates', function (req, res) {
  var requestData = "";
  req.on('data', function(chunk) {
      requestData += chunk
  });

  req.on('end', function () {
      var result = JSON.parse(requestData);
      var candidate = {
          name: result.name,
          bandVotes: 0,
          albumVotes: 0,
          id: nextId
      }

      nextId++;

      db = db.concat(candidate)

      res.jsonp(candidate)
  });
})

server.put('/candidates/:id', function (req, res) {
    var requestData = "";
    req.on('data', function(chunk) {
        requestData += chunk;
    });
    req.on('end', function () {
        var result = JSON.parse(requestData);
        var id = parseInt(req.params.id);
        console.log(id);
        console.log(db);
        if (db.hasOwnProperty(id)) {
            db[id].bandVotes = result.bandVotes;
            db[id].albumVotes = result.albumVotes;

            res.status(200).jsonp(db[id]);
        } else {
            res.status(400).jsonp("Could not find ID " + id);
        }
    });
})

server.delete('/candidates/:id', function (req, res) {
    var id = parseInt(req.params.id);
    if (db.hasOwnProperty(id)) {
        db.splice(id, 1);
        res.status(204).jsonp("{}");
    } else {
        res.status(404).jsonp("{}");
    }
});

server.get('/unauthorized', function (req, res) {
  res.sendStatus(401)
})

server.get('/not-found', function (req, res) {
  res.sendStatus(404)
})

// Use default middleware (logger, static, cors and no-cache)
var middlewares = jsonServer.defaults()
server.use(middlewares)

// Use default router
var router = jsonServer.router('db.json')
server.use(router)

server.listen(3000, function () {
  console.log()
  console.log('  🚀  Serving db.json on http://localhost:3000')
  console.log()
})
