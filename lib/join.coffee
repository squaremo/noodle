# Join algorithm on streams

{cons, NIL, fromArray, map, concatMap} = require('./sequence')

id = (s) -> s

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
    combines = {false: combine, true: (x, y) -> combine(y, x)}
    pred2s = {false: pred2, true: (x, y) -> pred2(y, x)}
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

(exports ? this).product = product
(exports ? this).join = join
