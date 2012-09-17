promise = require('./promise').promise

events = ->
    step = (sync) ->
        ((Cons, _Nil, _Skip) ->
                sync.then (cell) -> Cons(cell.car, cell.cdr))
    p = promise()
    inject = (v) ->
        old = p
        p = promise()
        old.resolve({car: v, cdr: step(p)})
    {stream: step(p), inject: inject}

(exports ? this).events = events
