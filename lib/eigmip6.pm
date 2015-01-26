use v6;

use com::jsyn::JSyn:from<Java>:jar<jsyn-20150105.jar>;
use com::jsyn::instruments::JSynInstrumentLibrary:from<Java>:jar<jsyn-20150105.jar>;
use com::jsyn::unitgen::SawtoothOscillatorDPW:from<Java>:jar<jsyn-20150105.jar>;
use com::jsyn::unitgen::LineOut:from<Java>:jar<jsyn-20150105.jar>;

module eigmip6;

enum Notes is export <C Cs D Ds E F Fs G Gs A As B>;

class Note is export {

    has Notes $.name = !!! 'canonical name for a note is required';

    has Num $.freq = !!! 'frequency of a note is required';

#`[[ not yet sure if this is actually useful
    method succ {
        my $newname = $.name.value == 11
            ?? Notes::C
            !! Notes($.name.value + 1);
        my $newfreq = $.freq * 13/12;
        Note.new(:name($newname), :freq($newfreq));
    }

    method pred {
        my $newname = $.name.value == 0
            ?? Notes::B
            !! Notes($.name.value - 1);
        my $newfreq = $.freq * 13/12;
        Note.new(:name($newname), :freq($newfreq));
    }
]]

}

multi infix:<+>(Note $lhs, Int $rhs) is export {
    Note.new(
        :name(Notes(($lhs.name + $rhs) % 12)),
        :freq(round($lhs.freq * 2 ** ($rhs / 12), 0.01).Num)
    );
}

multi infix:<+>(Int $lhs, Note $rhs) is export {
    $rhs + $lhs
}

multi infix:<->(Note $lhs, Int $rhs) is export {
    $lhs + -$rhs
}

multi infix:<->(Int $lhs, Note $rhs) is export {
    -$lhs + $rhs
}

class Scale is export {

    has Note $.root = !!! 'root note is required';

    has Int @.steps = !!! 'steps are required';

    has @!notes-cache;

#`[[ this is not particularly useful at the moment
    method notes {
        say "in notes";
        say @!notes-cache.defined;
        @!notes-cache.elems == @.steps + 1
        ?? @!notes-cache
        !! gather {
            say "in do";
            for [\+] @.steps {
                @!notes-cache.push: $.root + $_;
            }
            @!notes-cache
        }
    }
]]

    method !slot(Note $note) {
        (($.root.name - $note.name + @.steps) % @.steps) + 1;
    }

    method succ-note(Note $note) {
        $note + @.steps[self!slot($note)];
    }

    method pred-note(Note $note) {
        $note - @.steps[self!slot($note)];
    }

    method tritone(Note $root) {
        my $slot = self!slot($root);
        $root,
        $root + [+] @.steps[$slot..($slot + 2)],
        $root + [+] @.steps[$slot..($slot + 4)],
    }
}

my $lineout = LineOut.new;
my $synth = JSyn.createSynthesizer;

$synth.add( $lineout );
$synth.start;
$lineout.start;

my $pre-sync-chan;
my $post-sync-chan;

my @chans;
my @supps;
my @promises;

sub setGlobalTiming(Num $timing) is export {
    $pre-sync-chan = Channel.new;
    $post-sync-chan = Channel.new;
    @promises.push: start {
        my $supp = Supply.interval($timing / 1000);
        @supps.push: $supp;
        $supp.tap( -> $s {
                my $val = $pre-sync-chan.poll;
                $post-sync-chan.send($val) if $val;
            }
        )
    }
    True;
}

sub getNoteChannel (Num $update-interval = 1e0) is export {
    if !$pre-sync-chan || !$post-sync-chan {
        warn "please set a global timing with setGlobalTiming(<bpm>) first";
        return;
    }
    my $chan = Channel.new;
    @chans.push: $chan;

    my $osc = SawtoothOscillatorDPW.new;
    $synth.add( $osc );

    $osc.get_amplitude.set(0e0);

    $osc.get_output.connect( 0, $lineout.get_input, 0);
    $osc.get_output.connect( 0, $lineout.get_input, 1);

    $osc.get_amplitude.set(0.5e0);

    $pre-sync-chan.send(True);
    $post-sync-chan.receive;
    @promises.push: start {
        my $supp = Supply.interval($update-interval);
        @supps.push: $supp;
        $supp.tap(
        -> $s {
            $osc.noteOff;
            my $note = $chan.poll;
            # XXX: this is very hiding-what-we're-doing, maybe revisit
            my $freq = $note.?freq // $note.?Num;
            $osc.noteOn($freq, 1e0) if $note;
        }
    )};

    $osc.start;

    $chan;
}

sub closeAll is export {
    .close for @supps;
    .close for @chans;
    $pre-sync-chan.close;
    $post-sync-chan.close;
    await $_ for @promises;

    $synth.stop;
}
