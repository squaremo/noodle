# An event stream; that is, an object that gives us the head of a
# stream as well as a means to inject values. Since this will return
# without invoking continuations, doSeq will spin if you use it with
# an event stream. For that situation `doEvents` is provided; beware,
# though, that it will fill the stack if the underlying stream does
# *not* return without invoking continuations. Tricky!

promise = require('./promise').promise

events = ->
        step = (sync) ->
                (Cons, Nil, _Skip) ->
                        sync.then ((maybe) -> maybe(Cons, Nil))
        some = (value, sync) ->
                (Some, _None) -> Some(value, step(sync))
        none = (_Some, None) -> None()

        next = promise()
        inject = (v) ->
                old = next
                next = promise()
                old.resolve(some(v, next))
        stop = () ->
                next.resolve(none)
        {stream: step(next), inject: inject, stop: stop}

doEvents = (fn, stream) ->
        end = promise()
        next = (s) ->
                s(((v, r) -> fn(v); next(r)),
                (-> end.resolve(true)),
                ((r) -> next(r)))
        next(stream)
        end

asPromised = (p) ->
        (Cons, Nil, Skip) ->
                p.then((s) -> s(Cons, Nil, Skip))

exports = (exports ? this)
exports.events = events
exports.doEvents = doEvents
exports.asPromised = asPromised
