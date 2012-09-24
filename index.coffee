# All procedures, packaged for Node.JS or (server-side) Coffee Script.

for m in ['sequence', 'events', 'chars', 'node']
    for own k, v of require('./lib/' + m)
        module.exports[k] = v
