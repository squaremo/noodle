promise = require('./promise').promise

cons = (head, tailfn) ->
    (Cons, Nil, Skip) -> Cons(head, tailfn())

unfold = (seed, fn) ->
    (Cons, _Nil, _Skip) -> Cons(seed, unfold(fn(seed), fn))

take = (n, seq) ->
    (Cons, Nil, Skip) ->
        if n > 0
            seq(((v, r) -> Cons(v, take(n - 1, r))),
                 Nil,
                 ((r) -> Skip(take(n, r))))
        else
            Nil()

drop = (n, stream) ->
    if n > 0
        (Cons, Nil, Skip) ->
            stream(((_v, r) -> Skip(drop(n - 1, r))),
                    Nil,
                    ((r) -> Skip(drop(n, r))))
    else
        stream

tail = (stream) ->
    drop(1, stream)

filter = (pred, stream) ->
    (Cons, Nil, Skip) ->
        stream(((v, r) ->
            if pred(v)
                Cons(v, filter(pred, r))
            else
                Skip(filter(pred, r))), Nil, Skip)

map = (fn, a) ->
    (Cons, Nil, Skip) ->
        a(((v, r) -> Cons(fn(v), map(fn, r))), Nil, Skip)

# Ah now this is trickier, since we have to expose the otheriwse
# implicit state machine so that we can deal with skip.
zipWith = (fn, a, b) ->
    next = (aval, a, b) ->
        if aval != undefined
            (Cons, Nil, Skip) ->
                b(((v, r) ->
                    Cons(fn(aval, v), next(undefined, a, r))),
                  Nil,
                  ((r) -> Skip(next(aval, a, r))))
        else
            (Cons, Nil, Skip) ->
                a(((v, r) ->
                    Skip(next(v, r, b))),
                  Nil,
                  ((r) -> Skip(aval, r, b)))
    next(undefined, a, b)

lift = (unOp) ->
    (a) -> map(unOp, a)

lift2 = (binOp) ->
    (a, b) -> zipWith(binOp, a, b)

memoise = (stream) ->
    car = undefined; cdr = undefined
    (Cons, Nil, Skip) ->
        if car != undefined
            Cons(car, cdr)
        else if cdr != undefined
            Skip(cdr)
        else
            stream(((v, r) ->
                    car = v; cdr = memoise(r)
                    Cons(car, cdr)),
                   Nil,
                   ((r) -> cdr = r; Skip(r)))

# For each element of a yield an element of b instead. Useful if a is
# 'driving' the computation but b has the values you want; e.g., if
# you're counting things in a.
replace = (a, b) ->
    zipWith(((x, y) -> y), a, b)

iota = (start, step) ->
    unfold(start, (x) -> x + step)

nats = iota(0, 1)

fromArray = (arr) ->
    fromArray1 = (arr, i) -> (Cons, Nil) ->
        if i < arr.length then Cons(arr[i], fromArray1(arr, i+1)) else Nil()
    fromArray1(arr, 0)

## Problematic without recursion
# intoArray = (len, seq) ->
#     s = seq
#     res = []
#     while len > 0
#         s(((v, r) ->
#             res.push(v); s = r; len--), (-> len = 0))
#     res

# Here, we will spin until Nil is called, i.e., maybe forever.
# This'll also spin if the constructors aren't called immediately;
# e.g., if there's a promise at the far end that squirrels away the
# continuation instead of calling it.
doSeq = (fn, stream) ->
    s = stream
    while (s)
        s(((v, r) -> s = r; fn(v)), (-> s = false), ((r) -> s = r))
    s


exports = (exports ? this)

exports.cons = cons
exports.unfold = unfold
exports.tail = tail
exports.drop = drop
exports.take = take
exports.zipWith = zipWith
exports.map = map
exports.filter = filter
exports.memoise = memoise
exports.lift = lift
exports.lift2 = lift2

exports.replace = replace
exports.iota = iota
exports.nats = nats
exports.fromArray = fromArray
#exports.intoArray = intoArray

exports.doSeq = doSeq
