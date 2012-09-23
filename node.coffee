# For use with node's read and write streams, and especially pipe

events = require('./events')
Stream = require('stream').Stream

# Supply a read stream and get back a lazy sequence.
# %%% TODO Preserve back-pressure
fromStream = (read) ->
        ev = events.events()
        read.on('data', ev.inject)
        read.on('end', ev.stop)
        ev.stream

# Supply a sequence and get back a read stream
toStream = (seq) ->
        s = new Stream
        s.readable = true
        # paused, resume to set it going -- otherwise it'll just
        # play out before we can return it
        s.resume = (->
                end = events.doEvents(((d) -> s.emit('data', d)), seq)
                end.then(-> s.emit('end'))
                s)
        # It's convenient for one-liners if this also resumes
        # (%% though possibly semantics-breaking?)
        s.pipe = (out) ->
                Stream.prototype.pipe.call(s, out)
                s.resume()
        s

stream = (calculation) ->
        ev = events.events()
        c = calculation(ev.stream)
        s = new Stream
        s.readable = s.writable = true

        s.end = -> ev.stop; s.emit('end')

        # Backpressure. The way this works in node, we will get pause
        # invoked, at which point we want to start returning false to
        # writes; however, we still have to accept the data at least
        # once, to be able to return false to upstream.
        buf = []
        running = true
        s.pause = ->
                running = false
                s.write = (d) -> buf.push(d); false
        s.resume = ->
                running = true
                while buf.length > 0 && running
                        ev.inject(buf.shift())
                if buf.length == 0
                        s.emit('drain')
                if running
                        s.write = (d) -> ev.inject(d); true
        
        s.resume()
        end = events.doEvents(((d) -> s.emit('data', d)), c)
        end.then(s.emit('end'))
        s

exports = (exports ? this)
exports.stream = stream
exports.fromStream = fromStream
exports.toStream = toStream
