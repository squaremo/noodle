// Some fun with stream-like structures.

// This encoding is a procedure that accepts a menu of cons x nil and
// calls either cons with the value and another stream, or nil.

// 'S' for Scott-encoded

function fromArrayS(values) {

    function fromArray1(values, index) {
        return function(next, stop) {
            if (index < values.length) {
                next(values[index], fromArray1(values, index+1));
            }
            else {
                stop();
            }
        }
    }
    return fromArray1(values, 0);
}

function mapS(fn, s) {
    return function(next, stop) {
        s(function(value, rest) {
            next(fn(value), mapS(fn, rest));
        }, stop);
    };
}

function filterS(pred, stream) {
    function filter1(s) {
        return function(next, stop) {
            function val(value, rest) {
                if (pred(value)) {
                    next(value, filter1(rest));
                }
                else {
                    // there goes the stack.
                    rest(val, stop);
                }
            }
            s(val, stop);
        };
    }
    return filter1(stream);
}

function zipS(fn, a, b) {

    function zip1(a, b) {
        return function(next, stop) {
            a(function(valueA, restA) {
                b(function(valueB, restB) {
                    next(fn(valueA, valueB), zip1(restA, restB));
                }, stop);
            }, stop);
        };
    }
    return zip1(a, b);
}

function liftS(binOp) {
    return function(a, b) {
        return zipS(binOp, a, b);
    }
}

// OK so that was pretty nifty.

// However we have to deal with the fact that our stream values come
// from I/O, and thus are not demand-driven. For that reason it is
// more appropriate to have a callback-oriented interface; however,
// that makes `zip` rather awkward to define.

// A stream is a procedure that accepts a callback for values, and a
// continuation for when the values are exhausted.

function fromArrayD(values) {
    return function(next, stop) {
        values.forEach(function(value) {
            next(value);
        });
        stop();
    }
}

function map(fn, stream) {
    return function(next, stop) {
        stream(function(value) { next(fn(value)) },
               stop);
    };
}

function filter(pred, stream) {
    return function(next, stop) {
        stream(function(value) { if (pred(value)) next(value); },
               stop);
    };
}

function zip(f, a, b) {

    return function(next, stop) {
        function val(myBuf, otherBuf) {
            return function(value) {
                if (otherBuf.length > 0) {
                    next(f(value, otherBuf.shift()));
                } else {
                    myBuf.push(value);
                }
            };
        }
        var latch = 2;
        function dec() {
            latch--;
            if (latch === 0) stop();
        }
        var as = [], bs = [];
        a(val(as, bs), dec);
        b(val(bs, as), dec);
    }
}

// Yep, basically the same as above.
function lift(f) {
    return function(a, b) {
        return zip(f, a, b);
    }
}

// Another approach is to use promises to allow demand-driven
// calculations, but production-driven values.

/*
    var s = fromEvents(domNode, 'click');
    var displayAndLoop = function(next) {
      console.log(next.value);
      next.rest().then(displayAndLoop);
    }
    s.then(displayAndLoop);

*/

// Note: 1. We no longer have a 'stop' continuation -- the promise
// returned just never gets resolved; 2. the recursion (`rest`) is
// guarded with a closure, so we can generate values on demand,
// similarly to the implementation above.

// A stream is a promise that shall either resolve to an object
// containing the next value and a closure returning the rest of the
// stream.

// First an implementation of promises for our purpose.

function promise() {
    var success = [],
    failure = [],
    memo,
    resolved;

    function trigger(val, handlers) {
        memo = val;
        handlers.forEach(function(cb) { cb(val); });
    }

    return {
        resolve: function(value) {
            trigger(value, success);
            // let the handlers be collected
            success = true, failure = false;
        },
        reject: function(error) {
            trigger(value, failure);
            success = false, failure = true;
        },
        then: function(callback, errback) {
            if (success && memo !== undefined && callback) {
                callback(memo);
            }
            else if (errback && failure && memo !== undefined) {
                errback(memo);
            }
            else {
                if (callback) success.push(callback);
                if (errback) failure.push(errback);
            }
        }
    };
}

function fromArrayP(values) {
    function fromArray1(values, index) {
        if (index < values.length) {
            var p = promise();
            p.resolve({
                value: values[index],
                rest: function() {
                    return fromArray1(values, index+1);
                }
            });
            return p;
        }
        else {
            return promise();
        }
    }
    return fromArray1(values, 0);
}

function mapP(fn, s) {
    var p = promise();
    s.then(function(next) {
        p.resolve({
            value: fn(next.value),
            rest: function() {
                return mapP(fn, next.rest());
            }
        })
    });
    return p;
}

function filterP(pred, stream) {
    function doNext(s, p) {
        s.then(function(next) {
            if (pred(next.value)) {
                p.resolve({
                    value: next.value,
                    rest: function() {
                        return doNext(next.rest(), promise());
                    }
                });
            }
            else {
                doNext(next.rest(), p);
            }
        });
        return p;
    }
    return doNext(stream, promise());
}

function zipP(fn, a, b) {
    var p = promise();
    a.then(function(nextA) {
        b.then(function(nextB) {
            p.resolve({
                value: fn(nextA.value, nextB.value),
                rest: function() {
                    return zipP(fn, nextA.rest(), nextB.rest());
                }
            });
        });
    });
    return p;
}

function consP(val, rest) {
    var p = promise();
    p.resolve({
        value: val,
        rest: rest
    });
    return p;
}

function tailP(s) {
    var p = promise();
    s.then(function(next) {
        next.rest().then(function(next1) {
            p.resolve({
                value: next1.value,
                rest: next1.rest
            });
        });
    });
    return p;
}

/*

    fib = 0 : 1 : zipWith (+) fib (tail fib)

*/

function fib() {
    return consP(0, function() {
        return consP(1, function() {
            return zipP(plus, fib(), tailP(fib()));
        })});
}

function consolelog(v) {
    console.log(v);
}

function printLoopN(n) {
    return function(next) {
        consolelog(next.value);
        if (n > 1) {
            next.rest().then(printLoopN(n-1));
        }
    }
}

function project(s /* , keys */) {
    var keys = [].slice.call(arguments, 1);
    return mapP(function(obj) {
        var v = {};
        keys.forEach(function(k) {
            v[k] = obj[k];
        });
        return v;
    }, s);
}

// You can hook this up as an event handler:

function events() {
    var p = promise();
    var handle = function(event) {
        var old = p;
        p = promise();
        old.resolve({
            value: event,
            rest: function() {
                return p;
            }
        });
    };
    p.inject = handle;
    return p;
}

// Actually you can hook #1 up as an event handler too, using the
// promise implementation:

function eventsS() {
    var step = function(sync) {
        return function(cons, nil) {
            sync.then(function(cell) {
                cons(cell.value, cell.tail);
            });
        }
    }

    var p = promise();
    var handle = function(event) {
        var old = p;
        p = promise();
        old.resolve({value: event,
                     tail: step(p)});
    }
    
    var stream = step(p);
    stream.handler = handle;
    return stream;
}

// Can we do recursive streams a la the example above, with
// Scott-encoded sequences? Yes, so long as they are guarded by using
// consS.

function consS(head, tailF) {
    return function(cons, nil) {
        cons(head, tailF());
    }
}

function tailS(stream) {
    return function(cons, nil) {
        stream(function(_value, rest) {
            rest(cons, nil);
        }, function() { throw new Exception("Tail is nil"); });
    }
}

// function fib() {
//     return consP(0, function() {
//         return consP(1, function() {
//             return zipP(plus, fib(), tailP(fib()));
//         })});
// }

function fibS() {
    return consS(0, function() {
        return consS(1, function() {
            return liftS(plus)(fibS(), tailS(fibS()));
        });
    });
}

function takeS(n, stream) {
    return function(cons, nil) {
        if (n > 0) {
            stream(function(val, rest) {
                cons(val, takeS(n - 1, rest));
            }, nil);
        }
        else {
            nil();
        }
    };
}

function doS(fn, stream) {
    stream(function(val, rest) {
        fn(val);
        doS(fn, rest);
    }, function() {});
}
