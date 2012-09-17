promise = require('./promise').promise

cons = (head, tailfn) ->
    (Cons, Nil) -> Cons(head, tailfn())

unfold = (seed, fn) ->
    (Cons, _) -> Cons(seed, unfold(fn(seed), fn))

take = (n, seq) ->
    (Cons, Nil) ->
        if n > 0
            seq(((v, r) -> Cons(v, take(n - 1, r))), Nil)
        else
            Nil()

# Tricky. We can't avoid using up the stack (no tail call) unless we
# have our own stack. For small values of n (< 1000 say) just using
# the stack is OK though. But this is where the trouble starts.
drop = (n, stream) ->
    (Cons, Nil) ->
        dropped = (n, s) ->
            if n > 0
                s(((_v, r) -> dropped(n - 1, r)), Nil)
            else
                s(Cons, Nil)
        dropped(n, stream)

tail = (stream) ->
    drop(1, stream)

# Filter may have to recurse indefinitely!
filter = (pred, stream) ->
    (Cons, Nil) ->
        maybe = (v, r) ->
            if pred(v)
                Cons(v, filter(pred, r))
            else
                r(maybe, Nil)
        stream(maybe, Nil)

# Here, we will spin until Nil is called, i.e., maybe forever.
doSeq = (fn, stream) ->
    s = stream
    while (s)
        s(((v, r) -> s = r; fn(v)), (-> s = false))
    s

map = (fn, a) ->
    (Cons, Nil) ->
        a(((v, r) -> Cons(fn(a), map(fn, r))), Nil)

zipWith = (fn, a, b) ->
    (Cons, Nil) ->
        a(((av, ar) ->
            b(((bv, br) ->
                Cons(fn(av, bv), zipWith(fn, ar, br))), Nil)), Nil)

lift = (unOp) ->
    (a) -> map(unOp, a)

lift2 = (binOp) ->
    (a, b) -> zipWith(binOp, a, b)

memoise = (stream) ->
    car = null; cdr = null
    (Cons, Nil) ->
        if cdr != null
            Cons(car, cdr)
        else
            stream(((v, r) ->
                car = v; cdr = memoise(r)
                Cons(car, cdr)), Nil)

# For each element of a yield an element of b instead. Useful if a is
# 'driving' the computation but b has the values you want; e.g., if
# you're counting things in a.
replace = (a, b) ->
    (Cons, Nil) ->
        a(((_v, ar) ->
             b(((v, br) -> Cons(v, replace(ar, br))), Nil)), Nil)

iota = (start, step) ->
    unfold(start, (x) -> x + step)

nats = iota(0, 1)

fromArray = (arr) ->
    fromArray1 = (arr, i) -> (Cons, Nil) ->
        if i < arr.length then Cons(arr[i], fromArray1(arr, i+1)) else Nil()
    fromArray1(arr, 0)

intoArray = (len, seq) ->
    s = seq
    res = []
    while len > 0
        s(((v, r) ->
            res.push(v); s = r; len--), (-> len = 0))
    res

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
exports.intoArray = intoArray

exports.doSeq = doSeq
