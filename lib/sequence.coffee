# A stream is a procedure accepting three continuations:
# 
# Cons, yielding a value and the remaining stream;
# Nil, meaning the stream is done; and,
# Skip, giving the remaining stream and meaning the computation shall proceed with that remainder.
# 
# Including Skip allows us to write the stream combinators without
# recursion, so we won't blow the stack doing e.g.,
#     drop(1000000, nats).

NIL = (_C, Nil, _S) -> Nil()

cons = (head, tailfn) ->
    (Cons, Nil, Skip) -> Cons(head, tailfn())

unfold = (seed, fn) ->
    (Cons, _Nil, _Skip) -> Cons(seed, unfold(fn(seed), fn))

take = (n, seq) ->
    if n > 0
        (Cons, Nil, Skip) ->
            seq(((v, r) -> Cons(v, take(n - 1, r))),
                Nil,
                ((r) -> Skip(take(n, r))))
    else
        NIL

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
                        Skip(filter(pred, r))),
               Nil,
               ((r) -> Skip(filter(pred, r))))

map = (fn, a) ->
    (Cons, Nil, Skip) ->
        a(((v, r) -> Cons(fn(v), map(fn, r))),
          Nil,
          ((r) -> Skip(map(fn, r))))

# Expect the result of each application of the supplied function to itself return a sequence; concatenate these into one sequence.
concatMap = (fn, a) ->
    inner = (s, outerR) ->
        (Cons, Nil, Skip) ->
            s(((v, r) -> Cons(v, inner(r, outerR))),
              (() -> Skip(concatMap(fn, outerR))),
              ((r) -> Skip(inner(r, outerR))))
    (Cons, Nil, Skip) ->
        a(((v, r) -> Skip(inner(fn(v), r))), Nil, Skip)

# Return a stream of the values of fn, while reapplying it to each
# value in the stream.
reductions = (fn, seed, s) ->
    (Cons, Nil, Skip) ->
        s(((v, r) -> v1 = fn(seed, v); Cons(v1, reductions(fn, v1, r))),
          Nil,
          ((r) -> Skip(reductions(fn, seed, r))))

# Ah now this is trickier, since we have to expose the otherwise
# implicit state machine so that we can deal with skip.
zipWith = (fn, a, b) ->
    next = (aVal, a, b) ->
        #console.log({val: aVal, a: a.toString(), b: b.toString()})
        if aVal != undefined
            (Cons, Nil, Skip) ->
                b(((v, r) -> Cons(fn(aVal, v), next(undefined, a, r))),
                  Nil,
                  ((r) -> Skip(next(aVal, a, r))))
        else
            (Cons, Nil, Skip) ->
                a(((v, r) -> Skip(next(v, r, b))),
                  Nil,
                  ((r) -> Skip(next(undefined, r, b))))
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
                car = v; cdr = memoise(r); Cons(car, cdr)),
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

exports.NIL = NIL
exports.cons = cons
exports.unfold = unfold
exports.tail = tail
exports.drop = drop
exports.take = take
exports.zipWith = zipWith
exports.map = map
exports.filter = filter
exports.concatMap = concatMap
exports.reductions = reductions
exports.memoise = memoise
exports.lift = lift
exports.lift2 = lift2
        
exports.replace = replace
exports.iota = iota
exports.nats = nats
exports.fromArray = fromArray
#exports.intoArray = intoArray

exports.doSeq = doSeq
