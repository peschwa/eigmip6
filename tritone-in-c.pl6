use v6;

BEGIN die "You need to run this with perl6-j." unless $*VM ~~ /jvm/;

use com::jsyn::JSyn:from<Java>:jar<jsyn-20150105.jar>;
use com::jsyn::instruments::JSynInstrumentLibrary:from<Java>:jar<jsyn-20150105.jar>;
use com::jsyn::unitgen::SawtoothOscillatorDPW:from<Java>:jar<jsyn-20150105.jar>;
use com::jsyn::unitgen::LineOut:from<Java>:jar<jsyn-20150105.jar>;

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
    my ($root, $third, $fifth) = $num-to-Notes{$in, ($in + 4) % 12, ($in + 7) % 12};
    %notes{$root.key, $third.key, $fifth.key};
}

sub min($in) { 
    my ($root, $third, $fifth) = $num-to-Notes{$in, ($in + 3) % 12, ($in + 7) % 12};
    %notes{$root.key, $third.key, $fifth.key};
}

sub dim($in) {
    my ($root, $third, $fifth) = $num-to-Notes{$in, ($in + 3) % 12, ($in + 6) % 12};
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

my $lineoutInput = $lineout."field/get_input/Lcom/jsyn/ports/UnitInputPort;"();

for @oscs {
    $_.getOutput.connect(0, $lineoutInput, 0);
    $_.getOutput.connect(0, $lineoutInput, 1);
}

@oscs>>.start;
# ...and ends here

# jsyn probably has an interface for scheduling stuff, but Supplies are just too darn cool
Supply.new.interval(1).tap(
    -> $s { 
        unless rand < 0.1 {
            my ($r, $c) = %scale.pick.kv;
            my @n = $c($r.value);
            for ^3 Z @n -> $osc, $freq {
                say "osc $osc  freq $freq";
                @oscs[$osc].get_frequency.set($freq) 
            }
        }
    }
);

$*IN.getc;

$synth.stop;
