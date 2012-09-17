promise = ->
    success = []
    failure = []
    memo = null
    resolved = false

    trigger = (val, handlers) ->
        memo = val
        cb(val) for cb in handlers

    {
        resolve: ((value) ->
                trigger(value, success)
                resolved = success = true
                failure = false),

        reject: ((error) ->
                trigger(value, failure)
                success = false
                resolved = failure = true),

        then: ((callback, errback) ->
                if (resolved && success && callback)
                        callback(memo)
                else if (resolved && errback && failure)
                        errback(memo)
                else
                        success.push(callback) if callback
                        failure.push(errback) if errback)
    }

latch = (n) ->
        p = promise()
        p.decr = (-> n--; if n == 0 then p.resolve())
        p

exports = (exports ? this)
exports.promise = promise
exports.latch = latch
