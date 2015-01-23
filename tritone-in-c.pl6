use v6;

BEGIN die "You need to run this with perl6-j." unless $*VM ~~ /jvm/;

use com::jsyn::JSyn:from<Java>:jar<jsyn-20150105.jar>;
use com::jsyn::instruments::JSynInstrumentLibrary:from<Java>:jar<jsyn-20150105.jar>;
use com::jsyn::unitgen::SawtoothOscillatorDPW:from<Java>:jar<jsyn-20150105.jar>;
use com::jsyn::unitgen::LineOut:from<Java>:jar<jsyn-20150105.jar>;

use eigmip6;

enum Notes <C Cs D Ds E F Fs G Gs A As B>;
subset Note of Int where 0 <= * <= 11;
my %num-to-Notes = 0 => Notes::C, 1 => Notes::Cs, 2 => Notes::D,
                   3 => Notes::Ds, 4 => Notes::E, 5 => Notes::F,
                   6 => Notes::Fs, 7 => Notes::G, 8 => Notes::Gs,
                   9 => Notes::A, 10 => Notes::As, 11 => Notes::B;

my %notes = C => 261.63e0, Cs => 277.18e0, D => 293.66e0, Ds => 311.13e0, 
            E => 329.63e0, F => 349.23e0, Fs => 369.99e0, G => 392.00e0, 
            Gs => 415.30e0, A => 440.00e0, As => 466.16e0, B => 493.88e0;

sub maj($in) { 
    my ($root, $third, $fifth) = %num-to-Notes{$in, ($in + 4) % 12, ($in + 7) % 12};
    %notes{$root.key, $third.key, $fifth.key};
}

sub min($in) { 
    my ($root, $third, $fifth) = %num-to-Notes{$in, ($in + 3) % 12, ($in + 7) % 12};
    %notes{$root.key, $third.key, $fifth.key};
}

sub dim($in) {
    my ($root, $third, $fifth) = %num-to-Notes{$in, ($in + 3) % 12, ($in + 6) % 12};
    %notes{$root.key, $third.key, $fifth.key};
}

my %scale{Any} = Notes::C => &maj, 
                 Notes::D => &min, 
                 Notes::E => &min, 
                 Notes::F => &maj, 
                 Notes::G => &maj, 
                 Notes::A => &min, 
                 Notes::B => &dim;

# boilerplate starts here
my $lineout = LineOut.new;
my $synth = JSyn.createSynthesizer;

$synth.add($lineout);
$synth.start;
$lineout.start;

my @oscs;
@oscs.push( SawtoothOscillatorDPW.new ) for ^3;

for @oscs {
    $synth.add( $_ );
}

my $lineoutInput = $lineout.get_input;

for @oscs {
    $_.getOutput.connect(0, $lineoutInput, 0);
    $_.getOutput.connect(0, $lineoutInput, 1);
    $_.get_amplitude.set(0.1e0);
}

@oscs>>.start;
# ...and ends here

my $lead = SawtoothOscillatorDPW.new;
$synth.add($lead);
$lead.getOutput.connect(0, $lineoutInput, 0);
$lead.getOutput.connect(0, $lineoutInput, 1);
$lead.get_amplitude.set(0.1e0);
$lead.start;

my $bass = SawtoothOscillatorDPW.new;
$synth.add($bass);
$bass.getOutput.connect(0, $lineoutInput, 0);
$bass.getOutput.connect(0, $lineoutInput, 1);
$bass.get_amplitude.set(0.1e0);
$bass.start;

my $root;

sleep 1;

# jsyn probably has an interface for scheduling stuff, but Supplies are just too darn cool
start { Supply.interval(1).tap(
    -> $s { 
        unless rand < 0.1 {
            my $code;
            ($root, $code) = %scale.pick.kv;
            my @n = $code($root.value);
            for ^3 Z @n -> $osc, $freq {
                say "osc $osc, freq { $freq / 2 }, Note " ~ %notes.grep( *.value == $freq );
                @oscs[$osc].get_frequency.set($freq / 2) 
            }
        }
    }
) };

sleep 1;

start { Supply.interval(1/8).tap(
    -> $s {
        if ($s % 8) == 0|2|4 {
            $bass.noteOn(%notes{$root} / 4e0, 0.2e0);
        } 
        elsif ($s % 8) == 6 {
            my ($r, $c) = %scale{$root}.kv;
            my $note = $c($r).pick;
            $bass.noteOn($note / 4e0, 0.2e0);
        }
        else {
            $bass.noteOff;
        }
    })
};

sleep 4;

start { Supply.interval(1/4).tap( 
    -> $s {
        my $rnd = rand;
        if $rnd < 0.4 || $s %% 4 {
            my ($r, $c) = %scale{$root}.kv;
            my $note = $c($r).pick;
            #$note = $c(%scale{$note}.key).pick if rand < 0.1;
            say $note * 2;
            $lead.noteOn($note * 2, 0.1e0);
        }
        elsif 0.4 < $rnd < 0.8 {
            $lead.noteOff;
        }
        else {
            $lead.noteOff;
            sleep 1/8;
            $lead.noteOn(%notes{$root} * 2e0, 0.1e0);
        }
    })
};

#my $chan = Channel.new;
#
#for ^3 -> $num {
#    start { Supply.interval($num * rand).tap( { say "receiving"; @oscs[$num].get_frequency.set($chan.receive()) } ) };
#}
#
#Supply.interval(1).tap(
#    -> $s { 
#        unless rand < 0.1 {
#            say "sending";
#            my ($r, $c) = %scale.pick.kv;
#            my @n = $c($r.value);
#            for ^3 Z @n -> $osc, $freq {
#                #@oscs[$osc].get_frequency.set($freq) 
#                $chan.send($freq);
#            }
#        }
#    }
#);

$*IN.getc;

$synth.stop;
