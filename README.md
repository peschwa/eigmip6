# eigmip6 - Exploration in generative music in Perl 6

## DISCLAIMER

I'm dabbling. The current state works as described below, but the implementation of this module is far from finished. There will likely be noticeable jittering in playback in the current state. Also, it's probably rather loud. Also you currently probably have to terminate a Perl 6 REPL running with eigmip6 with ^C instead of ^D.

## What?

This repository contains my humble attempts at building something along the lines of [Extempore](https://github.com/digego/extempore) or [SuperCollider](http://supercollider.sourceforge.net/) in Perl 6, albeit (in contrast to Extempore at least) focused on music. The name is admittedly badly chosen, seeing as neither Extempore nor SuperCollider limit themselves to [generative music](http://en.wikipedia.org/wiki/Generative_music), but pride themselves with being useful for [live coding](http://en.wikipedia.org/wiki/Live_coding), which I am trying to emulate.

## OK, what's possible?

At the moment eigmip6 supports only the JVM backend of [Rakudo](http://www.rakudo.org). Running eigmip6 works with the following command line execute from the root of this repository

    CLASSPATH=3rdparty/jportaudio.jar:3rdparty/jsyn-20150105.jar perl6-j -Ilib -Meigmip6

assuming you have a Rakudo release 2015.01 or newer built for JVM in your path.

## Right, so I get the Perl 6 prompt. Great...?

eigmip6 currently exports exactly two subs, two types and an enum. (This is likely to change.) The subs exported are `&setGlobalTiming(Num)` and `&getNoteChannel(Num)`.

`&setGlobalTiming(Num)` takes a Num (write literals with scientific notation or coerce with .Num) and sets a global timing for synchronisation of note channels. This function at present always returns `True`.

`&getNoteChannel(Num)` takes an interval in milliseconds and creates a Supply which pulls data (i.e. frequencies) from a Channel. This Channel is returned and can be filled with frequency data by the user with the `.send()` method. Note that incoming data is coerced to Num internally. 

The exported enum is `Notes`, containing the Str literals `C Db D Eb E F Gb G Ab A Bb B`, which correspond to western musical notation.

The two types currently exported are `eigmip6::Note` and `eigmip6::Scale`. Suffice it to say that `Note` takes `:name` and `:freq`, the former is expected to be an element of the enum `Notes`, the latter a `Num`. `Scale` takes a `:root`, which has to be a `Note` and `:steps` which has to be an array of note steps that make the scale *including a 0 step as the first step* except if you want to leave out the root for some reason.

An example session:

    $ CLASSPATH=3rdparty/jportaudio.jar:3rdparty/jsyn-20150105.jar perl6-j -Ilib -Meigmip6
    > setGlobalTiming(1000e0);
    Jan 25, 2015 2:08:21 AM com.jsyn.engine.SynthesisEngine start
    INFO: Pure Java JSyn from www.softsynth.com, rate = 44100, RT, V16.7.4 (build 457, 2014-12-25)
    True
    > my $chan = getNoteChannel;
    Channel.new()
    > start { $chan.send($_) for (440, Any) xx * }
    Promise.new(scheduler => ThreadPoolScheduler.new(initial_threads => 0, max_threads => 16, uncaught_handler => Callable), status => PromiseStatus::Planned)
    >

The above is a transcript of feeding a lazy infinite list consisting of the Numeric literal 440 alternating with the type Any into a freshly created note channel. Reproducing this example on your machine should, provided a working audio interface exists and is not otherwise occupied, result in playback of 1 second of a 440hz sawtooth synth, followed by 1 second of silence, repeating.

