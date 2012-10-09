# An API for stream combinators; in particular, this allows partial
# applications of the combinators, and thereby 'flat' composition.

# We are going to have two types: a partially applied combinator, and
# a stream. A partial application allows composition, aka 'follows',
# via its methods. A stream allows operations on the stream via its
# methods; these will yield streams.

# Aside from making new streams, the Stream class has `each` which
# will run a procedure on each element of the stream for its
# side-effects, and `collect`, which collects the elements into an
# array.

# %% Can this be a functor (in the SML sense)

Seq = require('./sequence')
Rel = require('./relations')
promise = require('./promise').promise

# unary and binary refer to the number of streams to be supplied.

unary = (fn) ->
    (args...) ->
        if args.length is 1
            new UnaryPartial((s) -> fn(args[0], s))
        else if args.length is 2
            new Stream(fn(args[0], args[1].streamfn))
        else throw "Expected one or two arguments"

binary = (fn) ->
    (args...) ->
        if args.length is 1
            new BinaryPartial((a, b) -> fn(args[0], a, b))
        else if args.length is 2
            new UnaryPartial((b) ->
                fn(args[0], args[1].streamfn, b.streamfn))
        else if args.length is 3
            new Stream(fn(args[0], args[1].streamfn, args[2].streamfn))
        else throw "Expected one, two or three arguments"

# Streams: this way around gives us the combinators as methods; e.g.,
#
#     Stream(something).filter(isComment).map((s) -> s + '\n')

unaryM = (combo) -> ((fn) -> new Stream(combo(fn, @streamfn)))
# NB could also have a partial application here but meh
binaryM = (combo) ->
    ((fn, other) ->
        new Stream(combo(fn, @streamfn, other)))

# Run through a stream, applying the given procedure for its
# side-effect. This differs from doSeq and doEvents in that it will
# reschedule the loop when it detects that the continuation hasn't
# been invoked (i.e., the stream is waiting for I/O). Will still loop
# forever if the stream is infinite, of course.
 
# %% NB nextTick may not be available
doAll = (fn, stream) ->
    end = promise()
    s = stream; s1 = undefined
    go = ->
        while (s and s isnt s1)
            s1 = s
            s(((v, r) -> s = r; fn(v)), (-> s = false), ((r) -> s = r))
        if (s) then nextTick(go) else end.resolve(true)
    go()
    end

collect = (s) ->
    all = []
    done = promise()
    end = doAll(((el) -> all.push(el)), s)
    end.then(-> done.resolve(all)) # %% replace when promises chain
    done

class Stream
    constructor: (@streamfn) ->

    map: unaryM(Seq.map)
    filter: unaryM(Seq.filter)
    zipWith: binaryM(Seq.zipWith)
    concatMap: unaryM(Seq.concatMap)
    drop: unaryM(Seq.drop)
    take: unaryM(Seq.take)

    join: binaryM(Rel.join)
    project: unaryM(Rel.project)
    select: unaryM(Rel.select)
    equijoin: binaryM(Rel.equijoin)

    collect: (fn) -> done = collect(@streamfn); done.then(fn) if fn ?; done # %% Reconsider this, may be better to just return promise
    each : (fn) -> doAll(fn, @streamfn)

# ==== 'follows'
# 
# This way around we build up the transformation then apply it; e.g.,
#
# map(toString) . zipWith(plus) . apply(a, b)

unaryP = (combo) -> ((args...) ->
        inner = (args...) => @fn(combo(args...))
        unary(inner)(args...))

binaryP = (combo) -> ((args...) ->
        inner = (args...) => @fn(combo(args...))
        binary(inner)(args...))

class UnaryPartial

    # fn will eventually accept a sequence
    constructor: (@fn) ->

    apply: (s) -> new Stream(@fn(s.streamfn))

    map: unaryP(Seq.map)
    filter: unaryP(Seq.filter)
    zipWith: binaryP(Seq.zipWith)
    concatMap: unaryP(Seq.concatMap)
    take: unaryP(Seq.take)
    drop: unaryP(Seq.drop)
    
    join: binaryP(Rel.join)
    project: unaryP(Rel.project)
    select: unaryP(Rel.select)
    equijoin: binaryP(Rel.equijoin)

class BinaryPartial
    constructor: (@fn) ->

    apply: (a, b) -> new Stream(@fn(a.streamfn, b.streamfn))

# TODO: thread: ?
# thread(nats) . filter(odd) . map(frob)


# Entry points. These construct a stream or partial application
# depending on how many arguments are supplied.

exports = (exports ? this)
exports.stream = (seq) -> new Stream(seq) # %% Do I want to do some coercion here?
exports.isStream = (s) -> s instanceof Stream
exports.values = (args...) -> new Stream(Seq.fromArray(args))
exports.array = (a) -> new Stream(Seq.fromArray(a))

for f in ['map', 'filter', 'drop', 'take', 'concatMap']
    exports[f] = unary(Seq[f])

exports.zipWith = binary(Seq.zipWith)

exports.project = unary(Rel.project)
exports.join = binary(Rel.join)
exports.select = unary(Rel.select)
exports.equijoin = binary(Rel.equijoin)