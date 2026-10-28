# Privacy-first image metadata removal. Keep encoded image samples intact.
use strict;
use warnings;

sub privacy_box {
    my ($type, $body) = @_;
    die "Image container is too large to clean safely\n" if length($body) > 0xfffffff7;
    return pack('N', 8 + length($body)) . $type . $body;
}

sub privacy_boxes {
    my ($data, $start, $end) = @_;
    my @boxes;
    while ($start < $end) {
        die "Incomplete image container\n" if $end - $start < 8;
        my ($size, $type) = unpack('Na4', substr($data, $start, 8));
        my $header = 8;
        if ($size == 1) {
            die "Incomplete image container\n" if $end - $start < 16;
            $size = unpack('Q>', substr($data, $start + 8, 8));
            $header = 16;
        } elsif (!$size) { $size = $end - $start; }
        die "Invalid image container bounds\n" if $size < $header || $size > $end - $start;
        push @boxes, { type => $type, start => $start, body => $start + $header, end => $start + $size };
        $start += $size;
    }
    return @boxes;
}

sub privacy_uint {
    my ($data, $cursor, $size, $end) = @_;
    die "Unsupported image item layout\n" if $size > 8 || $$cursor + $size > $end;
    my $value = 0;
    $value = $value * 256 + ord(substr($data, $$cursor + $_, 1)) for 0 .. $size - 1;
    $$cursor += $size;
    return $value;
}

# Remove metadata item records AND erase their payloads. Keep the meta box at
# its original size with an empty free box, so no image-data offsets change.
sub privacy_heic {
    my ($path, $preserve_orientation) = @_;
    open my $fh, '<:raw', $path or die "Could not read image container\n";
    my $data = do { local $/; <$fh> };
    close $fh;
    my @top = privacy_boxes($data, 0, length($data));
    my @meta = grep { $_->{type} eq 'meta' } @top;
    die "Unsupported HEIC metadata layout\n" unless @meta == 1;
    my $meta = $meta[0];
    die "Unsupported HEIC metadata version\n" unless substr($data, $meta->{body}, 4) eq "\0\0\0\0";
    my @children = privacy_boxes($data, $meta->{body} + 4, $meta->{end});
    my %by_type;
    push @{$by_type{$_->{type}}}, $_ for @children;
    die "Unsupported HEIC item tables\n" unless @{$by_type{iinf} || []} == 1 && @{$by_type{iloc} || []} == 1;
    my %primary_metadata;
    if ($preserve_orientation) {
        die "Unsupported HEIC primary image\n" unless @{$by_type{pitm} || []} == 1;
        my $pitm = $by_type{pitm}[0];
        my $pv = ord(substr($data, $pitm->{body}, 1));
        die "Unsupported HEIC primary image version\n" if $pv > 1;
        my $q = $pitm->{body} + 4;
        my $primary = privacy_uint($data, \$q, $pv ? 4 : 2, $pitm->{end});
        for my $iref (@{$by_type{iref} || []}) {
            my $rv = ord(substr($data, $iref->{body}, 1));
            die "Unsupported HEIC reference version\n" if $rv > 1;
            for my $ref (privacy_boxes($data, $iref->{body} + 4, $iref->{end})) {
                next unless $ref->{type} eq 'cdsc';
                my $p = $ref->{body};
                my $id = privacy_uint($data, \$p, $rv ? 4 : 2, $ref->{end});
                my $num = privacy_uint($data, \$p, 2, $ref->{end});
                my @targets = map { privacy_uint($data, \$p, $rv ? 4 : 2, $ref->{end}) } 1 .. $num;
                $primary_metadata{$id} = 1 if grep { $_ == $primary } @targets;
            }
        }
    }
    my $iinf = $by_type{iinf}[0];
    my $version = ord(substr($data, $iinf->{body}, 1));
    die "Unsupported HEIC item information version\n" if $version > 1;
    my $count_size = $version ? 4 : 2;
    my $cursor = $iinf->{body} + 4;
    my $count = privacy_uint($data, \$cursor, $count_size, $iinf->{end});
    my @entries = privacy_boxes($data, $cursor, $iinf->{end});
    die "Invalid HEIC item count\n" unless @entries == $count;
    my (%remove, %items);
    for my $entry (@entries) {
        die "Unsupported HEIC item entry\n" unless $entry->{type} eq 'infe';
        my $v = ord(substr($data, $entry->{body}, 1));
        die "Unsupported HEIC item entry version\n" unless $v == 2 || $v == 3;
        my $p = $entry->{body} + 4;
        my $id = privacy_uint($data, \$p, $v == 2 ? 2 : 4, $entry->{end});
        my $protection = privacy_uint($data, \$p, 2, $entry->{end});
        die "Protected HEIC items cannot be cleaned\n" if $protection;
        die "Incomplete HEIC item type\n" if $p + 4 > $entry->{end};
        my $type = substr($data, $p, 4);
        die "Duplicate HEIC item identifier\n" if exists $items{$id};
        $items{$id} = $entry;
        $entry->{id} = $id;
        if ($type eq 'Exif' && $primary_metadata{$id}) { } # minimal orientation EXIF from the first pass
        elsif ($type eq 'Exif' || $type eq 'mime' || $type eq 'uri ') { $remove{$id} = 1; }
        elsif ($type !~ /^(hvc1|hev1|grid|iovl|iden|jpeg|av01|tmap)$/) {
            die "This HEIC item type cannot yet be cleaned safely\n";
        }
    }
    my $iloc = $by_type{iloc}[0];
    my $v = ord(substr($data, $iloc->{body}, 1));
    die "Unsupported HEIC item location version\n" if $v > 2;
    my $p = $iloc->{body} + 4;
    my $sizes = privacy_uint($data, \$p, 2, $iloc->{end});
    my ($os, $ls, $bs, $is) = (($sizes >> 12) & 15, ($sizes >> 8) & 15, ($sizes >> 4) & 15, $v ? $sizes & 15 : 0);
    my $n = privacy_uint($data, \$p, $v < 2 ? 2 : 4, $iloc->{end});
    my (@records, @erase, @keep_ranges);
    my %located;
    for (1 .. $n) {
        my $start = $p;
        my $id = privacy_uint($data, \$p, $v < 2 ? 2 : 4, $iloc->{end});
        die "Invalid HEIC item location\n" unless exists $items{$id} && !$located{$id}++;
        my $method = $v ? privacy_uint($data, \$p, 2, $iloc->{end}) & 15 : 0;
        my $reference = privacy_uint($data, \$p, 2, $iloc->{end});
        die "External HEIC data cannot be cleaned\n" if $reference || $method > 1;
        my $base = privacy_uint($data, \$p, $bs, $iloc->{end});
        my $extents = privacy_uint($data, \$p, 2, $iloc->{end});
        for (1 .. $extents) {
            privacy_uint($data, \$p, $is, $iloc->{end});
            my $offset = privacy_uint($data, \$p, $os, $iloc->{end});
            my $length = privacy_uint($data, \$p, $ls, $iloc->{end});
            next if !$length && $remove{$id}; # ExifTool leaves empty deleted items.
            my @containers = $method ? @{$by_type{idat} || []} : grep { $_->{type} eq 'mdat' } @top;
            die "Invalid HEIC inline data\n" if $method && @containers != 1;
            my $absolute = $base + $offset + ($method ? $containers[0]{body} : 0);
            die "Invalid HEIC data extent\n" unless $length && grep { $absolute >= $_->{body} && $absolute + $length <= $_->{end} } @containers;
            push @{ $remove{$id} ? \@erase : \@keep_ranges }, [$absolute, $length];
        }
        push @records, substr($data, $start, $p - $start) unless $remove{$id};
    }
    die "Incomplete HEIC metadata locations\n" if grep { !$located{$_} } keys %remove;
    for my $erase (@erase) {
        die "Metadata overlaps image data; no output was saved\n" if grep {
            $erase->[0] < $_->[0] + $_->[1] && $_->[0] < $erase->[0] + $erase->[1]
        } @keep_ranges;
        substr($data, $erase->[0], $erase->[1], "\0" x $erase->[1]);
    }
    my $body = substr($data, $meta->{body}, 4);
    for my $child (@children) {
        my $type = $child->{type};
        if ($type eq 'iinf') {
            my @kept = grep { !$remove{$_->{id}} } @entries;
            # Item names are descriptive strings; don't retain arbitrary labels.
            my $entries = join('', map {
                my $v = ord(substr($data, $_->{body}, 1));
                privacy_box('infe', substr($data, $_->{body}, $v == 2 ? 12 : 14) . "\0")
            } @kept);
            $body .= privacy_box($type, substr($data, $child->{body}, 4) . pack($count_size == 2 ? 'n' : 'N', scalar @kept) . $entries);
        } elsif ($type eq 'iloc') {
            $body .= privacy_box($type, substr($data, $child->{body}, 6) . pack($v < 2 ? 'n' : 'N', scalar @records) . join('', @records));
        } elsif ($type eq 'iref') {
            my $rv = ord(substr($data, $child->{body}, 1));
            die "Unsupported HEIC reference version\n" if $rv > 1;
            my $refs = '';
            for my $ref (privacy_boxes($data, $child->{body} + 4, $child->{end})) {
                my $q = $ref->{body};
                my $id = privacy_uint($data, \$q, $rv ? 4 : 2, $ref->{end});
                my $num = privacy_uint($data, \$q, 2, $ref->{end});
                my @ids = map { privacy_uint($data, \$q, $rv ? 4 : 2, $ref->{end}) } 1 .. $num;
                next if $remove{$id};
                die "Image depends on removed metadata\n" if $ref->{type} ne 'cdsc' && grep { $remove{$_} } @ids;
                @ids = grep { !$remove{$_} } @ids;
                next unless @ids;
                $refs .= privacy_box($ref->{type}, pack($rv ? 'N' : 'n', $id) . pack('n', scalar @ids) . join('', map { pack($rv ? 'N' : 'n', $_) } @ids));
            }
            $body .= privacy_box($type, substr($data, $child->{body}, 4) . $refs);
        } elsif ($type eq 'hdlr') {
            # Retain handler type, remove the free-form handler name.
            die "Invalid HEIC handler\n" if $child->{end} - $child->{body} < 24;
            $body .= privacy_box($type, substr($data, $child->{body}, 24) . "\0");
        } elsif ($type eq 'free' || $type eq 'skip' || $type eq 'dinf') {
            next;
        } elsif ($type eq 'iprp') {
            my $properties = '';
            for my $box (privacy_boxes($data, $child->{body}, $child->{end})) {
                if ($box->{type} eq 'ipco') {
                    for my $property (privacy_boxes($data, $box->{body}, $box->{end})) {
                        die "Unsupported HEIC image property; no output was saved\n"
                            unless $property->{type} =~ /^(hvcC|av1C|ispe|pixi|colr|irot|imir|clap|auxC|lsel|a1lx|a1op|pasp|clli|mdcv|ccst)$/;
                    }
                    $properties .= substr($data, $box->{start}, $box->{end} - $box->{start});
                } elsif ($box->{type} eq 'ipma') {
                    my $q = $box->{body};
                    my $flags = privacy_uint($data, \$q, 4, $box->{end});
                    my $pv = $flags >> 24;
                    die "Unsupported HEIC property association version\n" if $pv > 1;
                    my $num = privacy_uint($data, \$q, 4, $box->{end});
                    my @associations;
                    for (1 .. $num) {
                        my $start = $q;
                        my $id = privacy_uint($data, \$q, $pv ? 4 : 2, $box->{end});
                        my $n = privacy_uint($data, \$q, 1, $box->{end});
                        privacy_uint($data, \$q, $flags & 1 ? 2 : 1, $box->{end}) for 1 .. $n;
                        push @associations, substr($data, $start, $q - $start) unless $remove{$id};
                    }
                    die "Invalid HEIC property associations\n" unless $q == $box->{end};
                    $properties .= privacy_box('ipma', pack('NN', $flags, scalar @associations) . join('', @associations));
                } else { die "Unsupported HEIC property table\n"; }
            }
            $body .= privacy_box('iprp', $properties);
        } elsif ($type eq 'grpl') {
            my $groups = '';
            for my $group (privacy_boxes($data, $child->{body}, $child->{end})) {
                die "Unsupported HEIC image grouping\n" unless $group->{type} eq 'altr';
                my $q = $group->{body} + 8;
                my $num = privacy_uint($data, \$q, 4, $group->{end});
                my @ids = map { privacy_uint($data, \$q, 4, $group->{end}) } 1 .. $num;
                @ids = grep { !$remove{$_} } @ids;
                $groups .= privacy_box('altr', substr($data, $group->{body}, 8) . pack('N', scalar @ids) . pack('N*', @ids)) if @ids;
            }
            $body .= privacy_box($type, $groups);
        } elsif ($type =~ /^(pitm|idat)$/) {
            $body .= substr($data, $child->{start}, $child->{end} - $child->{start});
        } else { die "Unsupported HEIC metadata box; no output was saved\n"; }
    }
    my $replacement = privacy_box('meta', $body);
    my $padding = $meta->{end} - $meta->{start} - length($replacement);
    die "Could not preserve image offsets\n" if $padding < 0 || ($padding > 0 && $padding < 8);
    # Free padding belongs inside meta to keep the original top-level layout.
    $replacement = privacy_box('meta', $body . privacy_box('free', "\0" x ($padding - 8))) if $padding;
    substr($data, $meta->{start}, length($replacement), $replacement);
    # Other top-level optional metadata/trailers must not survive unnoticed.
    for my $box (@top) {
        next if $box->{type} =~ /^(ftyp|meta|mdat)$/;
        die "Unsupported HEIC container; no output was saved\n" unless $box->{type} =~ /^(free|skip|uuid|udta)$/;
        substr($data, $box->{start}, $box->{end} - $box->{start}, privacy_box('free', "\0" x ($box->{end} - $box->{start} - 8)));
    }
    open my $out, '>:raw', $path or die "Could not save cleaned container\n";
    print {$out} $data or die "Could not save cleaned container\n";
    close $out or die "Could not finish cleaned container\n";
}

sub privacy_clean {
    my ($source, $destination) = @_;
    my $reader = Image::ExifTool->new;
    $reader->Options(ImageHashType => 'SHA256', LargeFileSupport => 1);
    $reader->ImageInfo($source, '*', 'ImageDataHash', 'ICC_Profile');
    my $type = $reader->GetValue('FileType') || '';
    my $hash = $type eq 'GIF' ? gif_hash($source) : $reader->GetValue('ImageDataHash');
    die "The image data cannot be verified; no output was saved\n" unless $hash;
    my $writer = Image::ExifTool->new;
    $writer->Options(NoMandatory => 1, LargeFileSupport => 1);
    $writer->SetNewValue('all', undef, Protected => 1);
    # TIFF directories also contain image data and cannot be dropped wholesale.
    # Explicitly remove their supported descriptive entries as well.
    if ($type eq 'TIFF') {
        my $inspection = inspect($source, 0);
        for my $field (@{$inspection->{fields}}) {
            next unless $field->{removable} && $field->{scope} =~ /^(IFD\d+|ExifIFD|GPS|InteropIFD)( |$)/;
            $writer->SetNewValue($field->{write_target}, undef, Type => 'ValueConv', Protected => 1);
        }
    }
    # Keep only display/color essentials. Never copy maker notes, previews,
    # arbitrary XMP, or unknown camera-specific binary blocks back into output.
    $writer->SetNewValuesFromFile($source, 'ICC_Profile', 'Orientation',
        'PNG:Gamma', 'PNG:SRGBRendering', 'PNG:WhitePointX', 'PNG:WhitePointY',
        'PNG:RedX', 'PNG:RedY', 'PNG:GreenX', 'PNG:GreenY', 'PNG:BlueX', 'PNG:BlueY');
    die "Could not remove private metadata: " . ($writer->GetValue('Error') || 'unsupported image') . "\n"
        unless $writer->WriteInfo($source, $destination);
    privacy_heic($destination, defined $reader->GetValue('Orientation')) if $type eq 'HEIC' || $type eq 'HEIF';
    my $after = Image::ExifTool->new;
    $after->Options(ImageHashType => 'SHA256', LargeFileSupport => 1);
    $after->ImageInfo($destination, '*', 'ImageDataHash', 'MakerNotes');
    my $saved_hash = $type eq 'GIF' ? gif_hash($destination) : $after->GetValue('ImageDataHash');
    die "Image pixels changed; the output was rejected\n" unless defined($saved_hash) && $hash eq $saved_hash;
    for my $tag ($after->GetFoundTags) {
        next unless defined $after->GetValue($tag);
        my $g = $after->GetGroup($tag, 0);
        my $name = Image::ExifTool::GetTagName($tag);
        die "Private metadata remains; no output was saved\n"
            if $g =~ /^(MakerNotes|XMP|IPTC|Photoshop|JUMBF|PLIST)$/ || $name =~ /^MakerNote/;
        die "Private EXIF metadata remains; no output was saved\n"
            if $type =~ /^(JPEG|HEIC|HEIF)$/ && $g eq 'EXIF' && $name ne 'Orientation';
    }
    return 1;
}

1;
