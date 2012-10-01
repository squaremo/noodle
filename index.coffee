# All procedures, packaged for Node.JS or (server-side) Coffee Script.

for m in ['sequence', 'events', 'chars', 'node', 'join', 'relations']
    for own k, v of require('./lib/' + m)
        module.exports[k] = v
