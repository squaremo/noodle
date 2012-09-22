# An event stream; that is, an object that gives us the head of a
# stream as well as a means to inject values. Since this will return
# without invoking continuations, doSeq will spin if you use it with
# an event stream. For that situation `doEvents` is provided; beware,
# though, that it will fill the stack if the underlying stream does
# *not* return without invoking continuations. Tricky!

promise = require('./promise').promise

events = ->
        step = (sync) ->
                ((Cons, _Nil, _Skip) ->
                        sync.then ((fn) -> fn(Cons)))
        p = promise()
        inject = (v) ->
                old = p
                p = promise()
                old.resolve(((Cons) -> Cons(v, step(p))))
        {stream: step(p), inject: inject}

doEvents = (fn, stream) ->
        end = promise()
        next = (s) ->
                s(((v, r) -> fn(v); next(r)),
                (-> end.resolve(true)),
                ((r) -> next(r)))
        next(stream)
        end

exports = (exports ? this)
exports.events = events
exports.doEvents = doEvents
