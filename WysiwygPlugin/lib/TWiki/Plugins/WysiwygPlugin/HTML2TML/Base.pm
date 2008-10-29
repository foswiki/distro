# Abstract base class of node types
package TWiki::Plugins::WysiwygPlugin::HTML2TML::Base;

use Assert;

sub isLeafNode {
    my $node = shift;
    return ($node->{nodeType} == 3 || !$node->{head});
}

sub isBlockNode {
    return 0;
}

sub isTextNode {
    my $node = shift;
    return (isLeafNode($node) || isBlockNode($node));
}

# pure virtual
sub generate {
    ASSERT(0);
}

# pure virtual
sub addChild {
    ASSERT(0);
}

sub cleanNode {
}

sub hasClass {
    return 0;
}

sub cleanParseTree {
    my( $this, $opts ) = @_;

    my @jobs = ( $this );

    while (scalar(@jobs)) {
        my $node = shift(@jobs);
        $node->cleanNode($opts);

        my $prev;
        my $kid = $node->{head};
        while ($kid) {
            push(@jobs, $kid);
            $kid = $kid->{next};
        }
    }
    return ($this->{head}, $this->{head});
}

sub stringify {
    return '';
}

# Remove a node and all its children
sub _remove {
    my $this = shift;
    if ($this->{prev}) {
        $this->{prev}->{next} = $this->{next};
    } else {
        $this->{parent}->{head} = $this->{next};
    }
    if ($this->{next}) {
        $this->{next}->{prev} = $this->{prev};
    } else {
        $this->{parent}->{tail} = $this->{prev};
    }
    $this->{parent} = $this->{prev} = $this->{next} = undef;
}

# Remove a node, replacing it with its children. Return the first child.
sub _inline {
    my $this = shift;
    my $parent = $this->{parent};
    ASSERT($parent);
    my $fc = $this->{head};
    my $kid = $fc;
    while ($kid) {
        $kid->{parent} = $parent;
        $kid = $kid->{next};
    }
    if ($this->{head}) {
        if ($this->{prev}) {
            $this->{prev}->{next} = $this->{head};
            $this->{head}->{prev} = $this->{prev};
        } else {
            $parent->{head} = $this->{head};
        }
    }
    if ($this->{tail}) {
        if ($this->{next}) {
            $this->{next}->{prev} = $this->{tail};
            $this->{tail}->{next} = $this->{next};
        } else {
            $parent->{tail} = $this->{tail};
        }
    }
    $this->{parent} = $this->{prev} = $this->{next} = undef;
    return $fc;
}

sub _combineLeaves {
    my $this = shift;
    my $kid = $this->{head};
    return unless $kid;
    while (my $next = $kid->{next}) {
        if ($kid->isa('TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf') &&
              $next->isa('TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf')) {
            $kid->{text} .= $next->{text};
            $next->_remove();
        } else {
            $kid = $next;
        }
    }
}

# Determine if the node - and all it's child nodes - satisfy the criteria
# for an HTML inline element.
sub isInline {
    # This impl is actually for Nodes; Leaf overrides it
    my $this = shift;
    return 0 if $TWiki::Plugins::WysiwygPlugin::Constants::ALWAYS_BLOCK{uc($this->{tag})};
    my $kid = $this->{head};
    while ($kid) {
        return 0 unless $kid->isInline();
        $kid = $kid->{next};
    }
    return 1;
}

sub isLeftInline {
    # This impl is actually for Nodes; Leaf overrides it
    my $this = shift;
    return 0 if $TWiki::Plugins::WysiwygPlugin::Constants::ALWAYS_BLOCK{uc($this->{tag})};
    return 1 unless ($this->{head});
    return 0 unless $this->{head}->isInline();
    return 1;
}

sub isRightInline {
    my $this = shift;
    return 0 if $TWiki::Plugins::WysiwygPlugin::Constants::ALWAYS_BLOCK{uc($this->{tag})};
    return 1 unless $this->{tail};
    return 0 unless $this->{tail}->isInline();
    return 1;
}

# Determine if the previous node qualifies as an inline node
sub prevIsInline {
    my $this = shift;
    if ($this->{prev}) {
        return $this->{prev}->isRightInline();
    } elsif ($this->{parent}) {
        return $this->{parent}->prevIsInline();
    }
    return 0;
}

# Determine if the next node qualifies as an inline node
sub nextIsInline {
    my $this = shift;
    if ($this->{next}) {
        return $this->{next}->isLeftInline();
    } elsif ($this->{parent}) {
        return $this->{parent}->nextIsInline();
    }
    return 0;
}

1;
