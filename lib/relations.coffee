# Here we treat streams of objects as relations, and see what results.

{map, filter} = require('./sequence')
{join} = require('./join')

only = (fields) ->
    (object) ->
        r = {}
        r[k] = object[k] for k in fields
        r

# === Base procedures

# Take the specific fields from each object
project = (fields, stream) ->
    map(only(fields), stream)

# This may require us to make a little language for building a
# predicate -- except that it may as well be a closure
select = filter

equijoin = (fields, a, b) ->
    eq = (x, y) ->
        for f in fields
            if x[f] != y[f] then return false
        true
    merge = (x, y) ->
        r = {}
        r[k] = v for k, v of x
        r[k] = v for k, v of y # ok we'll double up a few
        r
    join(eq, merge, a, b)

exports = (exports ? this)
exports.project = project
exports.select = select
exports.equijoin = equijoin
