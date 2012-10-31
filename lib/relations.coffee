# Here we treat streams of objects as relations, and see what results.

{cons, NIL, fromArray, map, concatMap, filter} = require('./sequence')

id = (s) -> s

# === Base procedures

product = (combine, a, b) ->
# It would be nice to write it like this:
#     concatMap(((av) -> map(((bv) -> combine(av, bv)), b)), a)
# 
# However that will try to exhaust the inner sequence, which simply
# won't work if it is an unfold. So we have to 'alternate' between the
# sequences to keep producing values.
    combineflip = (x, y) -> combine(y, x)
    step = (a, b, as, bs, c1, c2) ->
        (Cons, Nil, Skip) ->
            a(((av, ar) ->
                    Cons(map(((bv) -> c1(av, bv)), bs),
                         step(b, ar, bs, cons(av, -> as), c2, c1))),
              (-> Skip(concatMap(((bv) -> map(((av) -> c1(av, bv)), as)), b))),
              ((r) -> Skip(step(r, b, as, bs, c1, c2))))
    concatMap(id, step(a, b, NIL, NIL, combine, combineflip))

join = (pred2, combine, a, b) ->
    step = (a, b, as, bs, flipped) ->
        c = if flipped then (x, y) -> combine(y, x) else combine
        p = if flipped then (x, y) -> pred2(y, x) else pred2
        (Cons, Nil, Skip) ->
            a(((av, ar) ->
                Cons(map(((bv) -> c(av, bv)),
                        filter(((bv) -> p(av, bv)), bs)),
                     step(b, ar, bs, cons(av, -> as), !flipped))),
              (-> Skip(concatMap(((bv) ->
                    map(((av) -> c(av, bv)),
                        filter(((av) -> p(av, bv)), as))), b))),
              ((r) -> Skip(next(r, b, as, bs, flipped))))
    concatMap(id, step(a, b, NIL, NIL, false))

# === Relational operators

only = (fields) ->
    (object) ->
        r = {}
        r[k] = object[k] for k in fields
        r

# Take the specific fields from each object
project = (fields, stream) ->
    map(only(fields), stream)

# This may require us to make a little language for building a
# predicate -- except that it may as well be a closure
select = filter

equijoin = (fields, a, b) ->
    eq = if Array.isArray(fields)
            (x, y) ->
                for f in fields
                    if x[f] != y[f] then return false
                true
        else
            (x, y) ->
                for fx, fy of fields
                    if x[fx] != y[fy] then return false
                true
    merge = (x, y) ->
        r = {}
        r[k] = v for k, v of x
        r[k] = v for k, v of y # ok we'll double up a few
        r
    join(eq, merge, a, b)


exports = (exports ? this)
exports.product = product
exports.join = join
exports.project = project
exports.select = select
exports.equijoin = equijoin
