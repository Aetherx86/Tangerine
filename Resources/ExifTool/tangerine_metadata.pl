#!/usr/bin/perl
# Tangerine's offline, fail-closed bridge to the unmodified ExifTool distribution.
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
BEGIN { $Image::ExifTool::configFile = ''; }
use Image::ExifTool;
use JSON::PP;
use Digest::SHA qw(sha256_hex);
use XML::Parser;
use File::Temp qw(tempdir);
use Image::ExifTool::Apple;
use Image::ExifTool::MakerNotes;

# Apple notes identify themselves with their own header. Their 64-bit TIFF
# entries remain valid even when the user deletes/edits the separate EXIF Make.
# Scope the format-16 compatibility context to this known maker-note format.
my $locate_ifd = \&Image::ExifTool::MakerNotes::LocateIFD;
{
    no warnings 'redefine';
    *Image::ExifTool::MakerNotes::LocateIFD = sub ($$) {
        my ($et, $dir) = @_;
        if (substr(${ $dir->{DataPt} }, $dir->{DirStart} || 0, 10) eq "Apple iOS\0") {
            local $et->{Make} = 'Apple';
            return $locate_ifd->(@_);
        }
        return $locate_ifd->(@_);
    };
}
$Image::ExifTool::Apple::Main{PROCESS_PROC} = sub {
    local $_[0]{Make} = 'Apple';
    return &Image::ExifTool::Exif::ProcessExif;
};
my $write_apple = $Image::ExifTool::Apple::Main{WRITE_PROC};
$Image::ExifTool::Apple::Main{WRITE_PROC} = sub {
    return $write_apple->() unless $_[0]; # ExifTool loads writers with a dummy call.
    local $_[0]{Make} = 'Apple';
    return $write_apple->(@_);
};
# By default, deleting permanent maker-note strings writes an empty value.
# These descriptive identifiers can be omitted from Apple's relative-offset IFD
# without affecting rendering. Leave all other maker-note definitions intact.
for my $id (0x0015, 0x0017, 0x002b) {
    $Image::ExifTool::Apple::Main{$id}{Permanent} = 0;
}

# Unknown XMP needs no writable schema for deletion. Parse XML to locate whole
# properties, then remove only their original byte ranges. Nested properties are
# explicitly presented as groups, never as independently writable flattened tags.
# No DTDs, entities, external resources, or image-supplied code are allowed.
sub custom_xmp {
    my ($packet, $namespaces, $properties) = @_;
    my (@stack, %entries);
    my $parser = XML::Parser->new(Handlers => {
        Doctype => sub { die "XMP document types are not supported\n" },
        ExternEnt => sub { die "External XMP entities are not supported\n" },
        Start => sub {
            my ($p, $name, %attrs) = @_;
            my %ns = @stack ? %{$stack[-1]{ns}} : ();
            for my $a (keys %attrs) { $ns{$1} = $attrs{$a} if $a =~ /^xmlns:(.*)$/; }
            my ($prefix, $local) = split /:/, $name, 2;
            my $description = @stack && $stack[-1]{description};
            my $unknown = defined($local) && ($namespaces->{$prefix} || $properties->{"$prefix:$local"});
            my $node = { ns => \%ns, start => $p->current_byte, name => $name,
                description => ($local // '') eq 'Description' && ($ns{$prefix} // '') eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' };
            $node->{target} = "XMP-$prefix:$local" if $description && $unknown;
            $stack[-1]{nested} = 1 if @stack;
            # RDF permits properties as attributes on rdf:Description too.
            if ($node->{description}) {
                my $start_tag = $p->original_string;
                while ($start_tag =~ /\s+([\w.:-]+)\s*=\s*(["'])(.*?)\2/sg) {
                    my ($attr, $value, $offset, $length) = ($1, $3, $-[0], $+[0] - $-[0]);
                    my ($ap, $al) = split /:/, $attr, 2;
                    next unless defined($al) && $ap ne 'xmlns' && ($namespaces->{$ap} || $properties->{"$ap:$al"});
                    my $entry = $entries{"XMP-$ap:$al"} ||= { scope => "XMP-$ap", key => $al, ranges => [] };
                    push @{$entry->{ranges}}, [$node->{start} + $offset, $length];
                    $entry->{value} = $attrs{$attr};
                }
            }
            push @stack, $node;
        },
        Char => sub { my ($p, $text) = @_; $stack[-1]{text} .= $text if @stack; },
        End => sub {
            my ($p) = @_;
            my $node = pop @stack;
            return unless $node->{target};
            my ($scope, $key) = split /:/, $node->{target}, 2;
            my $entry = $entries{$node->{target}} ||= { scope => $scope, key => $key, ranges => [] };
            my $end = $p->current_byte;
            # Empty elements have their End event immediately after the start tag.
            $end += length($p->original_string) if substr($packet, $end, 2) eq '</';
            push @{$entry->{ranges}}, [$node->{start}, $end - $node->{start}];
            $entry->{value} = $node->{nested} ? 'Grouped metadata - remove together' : ($node->{text} // '');
        },
    });
    $parser->parse($packet);
    for my $entry (values %entries) {
        $entry->{value} = 'Repeated metadata - remove together' if @{$entry->{ranges}} > 1;
        $entry->{original} = $entry->{value};
        $entry->{editable} = JSON::PP::false;
        $entry->{removable} = JSON::PP::true;
        $entry->{removed} = JSON::PP::false;
        $entry->{custom} = 1;
    }
    return [values %entries];
}

# Older ImageIO outputs can contain these non-standard XMP properties alongside
# the real GPS coordinates. Register the literal legacy fields so their removal
# does not depend on a user's ExifTool configuration or leave location remnants.
Image::ExifTool::AddUserDefinedTags('Image::ExifTool::XMP::exif',
    map { $_ => { Writable => 'string' } } qw(GPSLatitudeRef GPSLongitudeRef GPSDestLatitudeRef GPSDestLongitudeRef));

# Canva exports these custom XMP schemas. ExifTool can read unknown properties,
# but needs their structure to write individual leaves without deleting siblings.
# Register data-only schemas locally; never load configuration from an image.
our %CanvaAttribution = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-Attrib', 2 => 'Other' },
    NAMESPACE => { Attrib => 'http://ns.attribution.com/ads/1.0/' },
    Ads => {
        List => 'Seq',
        Struct => {
            STRUCT_NAME => 'Canva Attribution',
            NAMESPACE => 'Attrib',
            map { $_ => { Writable => 'string' } } qw(Created Data ExtId FbId TouchType),
        },
    },
);
our %CanvaAIContent = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-ContainsAiGeneratedContent', 2 => 'Other' },
    NAMESPACE => { ContainsAiGeneratedContent => 'https://canva.com/export' },
    ContainsAiGeneratedContent => { Writable => 'string' },
);
Image::ExifTool::AddUserDefinedTags('Image::ExifTool::XMP::Main',
    Attrib => { SubDirectory => { TagTable => 'main::CanvaAttribution' } },
    ContainsAiGeneratedContent => { SubDirectory => { TagTable => 'main::CanvaAIContent' } });

my ($mode, $source, $destination, $plan_path) = @ARGV;
die "Invalid metadata request\n" unless defined $source && ($mode eq 'read' || $mode eq 'write');

sub text_value {
    my ($value) = @_;
    return join("\n", map { text_value($_) } @$value) if ref($value) eq 'ARRAY';
    return '[Binary data]' if ref($value) eq 'SCALAR';
    return JSON::PP->new->canonical->encode($value) if ref($value);
    return defined($value) ? "$value" : '';
}

# GIF is not covered by ExifTool's ImageDataHash. Hash the complete rendering
# stream: header, palettes, image descriptors, compressed blocks, timing,
# disposal and loop-control extensions. Only comment/XMP/ICC metadata is omitted.
sub gif_hash {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Could not read GIF\n";
    my $sha = Digest::SHA->new(256);
    my $read = sub {
        my ($count) = @_;
        my $bytes = '';
        while (length($bytes) < $count) {
            my $got = read($fh, my $chunk, $count - length($bytes));
            die "Incomplete GIF\n" unless $got;
            $bytes .= $chunk;
        }
        return $bytes;
    };
    my $header = $read->(13);
    die "Invalid GIF\n" unless $header =~ /^GIF8[79]a/;
    $sha->add($header);
    my $packed = ord(substr($header, 10, 1));
    $sha->add($read->(3 * (2 << ($packed & 7)))) if $packed & 128;
    my $blocks = sub {
        my ($keep) = @_;
        while (1) {
            my $size = $read->(1);
            my $block = $read->(ord($size));
            $sha->add($size, $block) if $keep;
            last unless ord($size);
        }
    };
    while (1) {
        my $marker = $read->(1);
        if ($marker eq ';') { $sha->add($marker); last; }
        if ($marker eq ',') {
            my $descriptor = $read->(9);
            $sha->add($marker, $descriptor);
            my $flags = ord(substr($descriptor, 8, 1));
            $sha->add($read->(3 * (2 << ($flags & 7)))) if $flags & 128;
            $sha->add($read->(1));
            $blocks->(1);
        } elsif ($marker eq '!') {
            my $label = $read->(1);
            if (ord($label) == 255) {
                my $size = $read->(1);
                my $app = $read->(ord($size));
                my $keep = $app !~ /^(XMP DataXMP|ICCRGBG1012)/;
                $sha->add($marker, $label, $size, $app) if $keep;
                $blocks->($keep);
            } else {
                my $keep = ord($label) != 254;
                $sha->add($marker, $label) if $keep;
                $blocks->($keep);
            }
        } else { die "Unsupported GIF block\n"; }
    }
    close $fh;
    return $sha->hexdigest;
}

sub inspect {
    my ($path, $verify) = @_;
    my $et = Image::ExifTool->new;
    $et->Options(Duplicates => 1, Unknown => 0, RequestAll => 0, PrintConv => 0,
                 ImageHashType => 'SHA256', LargeFileSupport => 1);
    my @wanted = ('*', 'XMP', 'JUMBF');
    push @wanted, 'ImageDataHash', 'ICC_Profile', 'ThumbnailImage', 'PreviewImage' if $verify;
    my $info = $et->ImageInfo($path, @wanted);
    die "Could not read image metadata: " . ($et->GetValue('Error') || 'unknown error') . "\n" if $et->GetValue('Error');
    my @fields;
    my $probe = Image::ExifTool->new;
    my %counts;
    my %invariants;
    my (%unknown_ns, %unknown_props, %protected_ns);
    my $packet = '';
    my $toolkit;
    for my $tag (keys %$info) {
        next unless $et->GetGroup($tag, 0) eq 'XMP';
        my $document = $et->GetGroup($tag, 3);
        my $name = Image::ExifTool::GetTagName($tag);
        if ($name eq 'XMP') {
            my $raw = $et->GetValue($tag, 'ValueConv');
            next unless ref($raw) eq 'SCALAR';
            if ($document eq 'Main') { $packet = $$raw; }
            elsif ($verify) { $invariants{"Auxiliary XMP:$document"} = sha256_hex($$raw); }
        } elsif ($name eq 'XMPToolkit' && $document eq 'Main') {
            $toolkit = $et->GetValue($tag, 'ValueConv');
        }
    }
    my $jumbf = $et->GetValue('JUMBF', 'ValueConv');
    my $hash = $verify ? $et->GetValue('ImageDataHash') : undef;
    my $type = $et->GetValue('FileType') || '';
    $hash = gif_hash($path) if $verify && $type eq 'GIF';
    die "This image's encoded data cannot be verified safely. No output was saved.\n" if $verify && !$hash;
    foreach my $tag ($et->GetFoundTags('File')) {
        my $group = $et->GetGroup($tag, 1);
        next if $group =~ /^(System|ExifTool|Composite)$/ || $et->GetGroup($tag, 0) eq 'Composite';
        my $name = Image::ExifTool::GetTagName($tag);
        next if $name eq 'ImageDataHash' || $name eq 'XMP';
        # Content credentials are a signed unit. Expose one explicit removal
        # action instead of pretending their hashes and assertions are editable.
        next if $jumbf && ($name eq 'JUMBF' || $et->GetGroup($tag, 0) eq 'JUMBF');
        my $value = $et->GetValue($tag, 'ValueConv');
        my $target = "$group:$name";
        my $tag_info = $et->{TAG_INFO}{$tag} || {};
        my $rendering = $group =~ /^(ICC|ICC_Profile|JFIF|Adobe)/ || $name =~ /^(Orientation|ColorSpace|Gamma|SRGBRendering|RenderingIntent|WhitePoint|PrimaryChromaticities|TransferFunction|YCbCr.*|ComponentsConfiguration|ImageWidth|ImageHeight|ExifImageWidth|ExifImageHeight|BitsPerSample|SamplesPerPixel|Compression|PhotometricInterpretation|PlanarConfiguration|ExtraSamples|Tile.*|Strip.*|RowsPerStrip|Predictor|FillOrder|SampleFormat|XResolution|YResolution|ResolutionUnit|PixelAspectRatio|BackgroundColor|TransparentColor|Animation.*|Frame.*|LoopCount|Delay|Disposal|ICC_Profile|ThumbnailImage|PreviewImage)$/;
        # The container writer only edits metadata belonging to the primary
        # image. Auxiliary portrait/depth/HDR packets must remain byte-identical.
        my $auxiliary_xmp = $et->GetGroup($tag, 0) eq 'XMP' && $et->GetGroup($tag, 3) ne 'Main';
        my $binary = ref($value) eq 'SCALAR';
        $rendering ||= $group =~ /^(MPF|HDRGainMap|XMP-(hdrgm|crs|apdi|apple.*|portraitEffectsMatte))$/i
            || $name =~ /^(GainMap.*|HDR.*|ColorMatrix.*|CameraCalibration.*|CalibrationIlluminant.*|AsShot.*|AnalogBalance|BlackLevel.*|WhiteLevel|DefaultCrop.*|DefaultScale|OpcodeList.*)$/;
        $rendering ||= $name =~ /^(BitDepth|ColorType|ColorResolutionDepth|BitsPerPixel|HasColorMap|Interlace|Filter|PixelsPerUnitX|PixelsPerUnitY|PixelUnits|ProfileName|Rotation|Mirror|MatrixStructure|ColorPrimaries|TransferCharacteristics|MatrixCoefficients|VideoFullRangeFlag|ImageSpatialExtent|ImagePixelDepth)$/;
        # Descriptive EXIF/XMP dimensions and print-resolution hints are not the
        # encoded image's dimensions. Likewise, metadata version tags are not
        # codec headers. Do not confuse ExifTool's explicit-write protection with
        # information needed to display the image.
        my $descriptive = ($group =~ /^(ExifIFD|XMP-)/ && $name =~ /^(ExifImageWidth|ExifImageHeight|ImageWidth|ImageHeight)$/)
            || ($group =~ /^(IFD\d+|ExifIFD|XMP-)/ && $name =~ /^(XResolution|YResolution|ResolutionUnit)$/);
        $rendering = 0 if $descriptive;
        $rendering ||= $auxiliary_xmp;
        my $protected = $rendering || ($group eq 'File' && $name ne 'Comment');
        if ($group =~ /^XMP-(.*)$/) {
            my $ns = $1;
            $protected_ns{$ns} = 1 if $protected;
            if (!$protected && $tag_info->{IsDefault}) {
                if (($tag_info->{Table}{TABLE_NAME} // '') eq 'Image::ExifTool::XMP::other') {
                    $unknown_ns{$ns} = 1;
                } else {
                    $unknown_props{"$ns:$tag_info->{TagID}"} = 1;
                }
            }
        }
        # IsWritable alone ignores the group and may find a writable namesake in
        # another format (for example PNG's read-only BitDepth). Load the writer,
        # then consult this exact extracted tag's table instead.
        Image::ExifTool::IsWritable($target) unless $protected || $binary;
        my $capability = defined($tag_info->{Writable}) ? $tag_info->{Writable} : $tag_info->{Table}{WRITABLE};
        my $writable = !$protected && !$binary && $capability && !$tag_info->{SubDirectory};
        if ($writable) {
            my ($accepted) = $probe->SetNewValue($target, undef, Type => 'ValueConv', Protected => 1);
            $writable = $accepted ? 1 : 0;
        }
        my $text = text_value($value);
        my $copy = $counts{$target}++;
        push @fields, { scope => $group, key => $name, original => $text, value => $text,
            editable => $writable && (ref($value) eq '' || (ref($value) eq 'ARRAY' && !grep { ref($_) } @$value)) ? JSON::PP::true : JSON::PP::false,
            removable => $writable ? JSON::PP::true : JSON::PP::false,
            list => ref($value) eq 'ARRAY' ? JSON::PP::true : JSON::PP::false,
            removed => JSON::PP::false, copy => $copy };
        # Container rewrites may relocate unchanged data; offsets are not part of
        # appearance and the referenced compressed payload is hashed separately.
        if ($verify && $name !~ /^(StripOffsets|TileOffsets|ThumbnailOffset|PreviewImageStart|JpgFromRawStart|MediaData)$/
            && ($rendering || ($binary && $name !~ /(Digest|Checksum)$/))) {
            $invariants{"$target:$copy"} = $binary ? sha256_hex($$value) : $text;
        }
    }
    if ($packet && (%unknown_ns || %unknown_props)) {
        delete $unknown_ns{$_} for keys %protected_ns;
        delete $unknown_props{$_} for grep { my ($ns) = split /:/; $protected_ns{$ns} } keys %unknown_props;
        my $custom = custom_xmp($packet, \%unknown_ns, \%unknown_props);
        my %custom_targets = map { ("$_->{scope}:$_->{key}" => 1) } @$custom;
        @fields = grep {
            my $ns = $_->{scope}; $ns =~ s/^XMP-//;
            !$unknown_ns{$ns} && !$custom_targets{"$_->{scope}:$_->{key}"}
        } @fields;
        push @fields, @$custom;
    }
    if ($jumbf) {
        push @fields, { scope => 'Metadata groups', key => 'Content credentials',
            value => 'Signed metadata - remove entire group', original => 'Signed metadata - remove entire group',
            removable => JSON::PP::true, editable => JSON::PP::false, removed => JSON::PP::false, block => 'JUMBF' };
        $invariants{'Metadata groups:JUMBF'} = sha256_hex($$jumbf) if $verify;
    }
    # A single write selector can affect repeated tags in the same group.
    # Keep them addressable in the UI but route write/verification through
    # the base scope so selection removes all copies consistently.
    foreach my $field (@fields) {
        next if $field->{custom} || $field->{block};
        $field->{write_target} = "$field->{scope}:$field->{key}";
        if (($counts{"$field->{scope}:$field->{key}"} || 0) > 1) {
            $field->{scope} .= ' (copy ' . ($field->{copy} + 1) . ')';
            $field->{editable} = JSON::PP::false;
            # Repetition must not make protected rendering data writable.
        }
        delete $field->{copy};
    }
    return { fields => \@fields, hash => $hash, invariants => \%invariants, packet => $packet, toolkit => $toolkit };
}

my $json = JSON::PP->new->utf8->canonical;
if ($mode eq 'read') {
    my $inspection = inspect($source, 0);
    delete $inspection->{packet};
    print $json->encode($inspection);
    exit;
}
die "Missing save destination\n" unless defined $destination && defined $plan_path && !-e $destination;
open my $plan_file, '<:raw', $plan_path or die "Could not read metadata changes\n";
my $plan = $json->decode(do { local $/; <$plan_file> });
close $plan_file;
if ($plan->{removeAll}) {
    require "$FindBin::Bin/tangerine_privacy.pl";
    privacy_clean($source, $destination);
    print $json->encode({ verified => JSON::PP::true });
    exit;
}
my $before = inspect($source, 1);
my %allowed = map { ("$_->{scope}:$_->{key}" => $_) } @{$before->{fields}};
my @changes = @{$plan->{changes} || []};
if ($plan->{removeAll}) {
    @changes = map { { %$_, removed => JSON::PP::true } } grep { $_->{removable} } @{$before->{fields}};
}
my $writer = Image::ExifTool->new;
my %custom_changes;
$writer->Options(NoMandatory => 1, LargeFileSupport => 1);
# Some PNG exports have an empty EXIF directory pointing into JUMBF. Rewriting
# that directory may synthesize this default even with NoMandatory; suppress
# synthesis, but never remove an existing appearance tag implicitly.
$writer->SetNewValue('IFD0:YCbCrPositioning', undef, Protected => 1)
    unless exists $allowed{'IFD0:YCbCrPositioning'};
# Do not stamp the file with ExifTool's own toolkit string when another field is
# edited. A user-selected toolkit edit/removal below overrides this preservation.
$writer->SetNewValue('XMP-x:XMPToolkit', $before->{toolkit}, Type => 'ValueConv', Protected => 1);
foreach my $change (@changes) {
    my $target = "$change->{scope}:$change->{key}";
    my $field = $allowed{$target};
    die "This metadata field cannot be changed safely\n" unless $field && $field->{removable};
    die "The source metadata changed. Reopen the editor.\n" unless $plan->{removeAll} || $field->{original} eq $change->{original};
    my $value = $change->{removed} ? undef : $change->{value};
    die "This field supports removal only\n" if defined($value) && !$field->{editable};
    if ($field->{custom}) { $custom_changes{$target} = 1; next; }
    if ($field->{block}) {
        $target = $field->{block};
        delete $before->{invariants}{"Metadata groups:$target"};
        $target .= ':all';
    }
    $value = [split(/\n/, $value, -1)] if defined($value) && $field->{list};
    my $write_target = $field->{write_target} // $target;
    my ($count, $error) = $writer->SetNewValue($write_target, $value, Type => 'ValueConv', Protected => 1);
    die "Could not change $target: " . ($error || 'unsupported tag') . "\n" unless $count;
}
my $stage_dir = %custom_changes ? tempdir('tangerine-xmp-XXXXXX', TMPDIR => 1, CLEANUP => 1) : undef;
my $stage = $stage_dir ? "$stage_dir/image" : $destination;
my $expected_packet;
my $result = $writer->WriteInfo($source, $stage);
die "Could not save image metadata: " . ($writer->GetValue('Error') || 'unsupported image') . "\n" unless $result;
if (%custom_changes) {
    my $intermediate = inspect($stage, 1);
    my $packet = $intermediate->{packet};
    my @ranges;
    for my $field (@{$intermediate->{fields}}) {
        push @ranges, @{$field->{ranges}} if $custom_changes{"$field->{scope}:$field->{key}"} && $field->{custom};
    }
    for my $range (sort { $b->[0] <=> $a->[0] } @ranges) {
        substr($packet, $range->[0], $range->[1], '');
    }
    my $raw_writer = Image::ExifTool->new;
    $expected_packet = $packet;
    # This is an explicitly selected, byte-preserving packet replacement.
    # Without Protected, ExifTool skips the XMP block and may accept a namesake
    # from another format instead, leaving the original properties untouched.
    my ($accepted, $error) = $raw_writer->SetNewValue('XMP:XMP', $packet, Type => 'ValueConv', Protected => 1);
    die "Could not update custom XMP metadata: " . ($error || 'unsupported packet') . "\n" unless $accepted;
    die "Could not remove custom XMP metadata\n" unless $raw_writer->WriteInfo($stage, $destination);
}
my $after = inspect($destination, 1);
die "Unselected XMP metadata changed; the output was rejected\n"
    if defined($expected_packet) && $after->{packet} ne $expected_packet;
die "Image data changed; the output was rejected\n" unless $before->{hash} eq $after->{hash};
if ($json->encode($before->{invariants}) ne $json->encode($after->{invariants})) {
    my %keys = map { $_ => 1 } (keys %{$before->{invariants}}, keys %{$after->{invariants}});
    my @changed = grep { ($before->{invariants}{$_} // '') ne ($after->{invariants}{$_} // '') } sort keys %keys;
    die "Image appearance information changed (" . join(', ', @changed) . "); the output was rejected\n";
}
my %saved = map { (($_->{write_target} // "$_->{scope}:$_->{key}") => $_) } @{$after->{fields}};
foreach my $change (@changes) {
    my $target = "$change->{scope}:$change->{key}";
    my $write_target = $allowed{$target}{write_target} // $target;
    my $applied = $saved{$write_target};
    if ($change->{removed}) {
        die "The format did not apply the change to $target\n" if defined($applied);
    } else {
        die "The format did not apply the change to $target\n" unless defined($applied) && $applied->{value} eq $change->{value};
    }
}
print $json->encode({ verified => JSON::PP::true });
