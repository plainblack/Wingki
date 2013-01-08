package Wingki::DB::Result::Wiki;

use Moose;
use Wing::Perl;
use Ouch;
extends 'Wing::DB::Result';

with 'Wing::Role::Result::Field';
with 'Wing::Role::Result::UriPart';

__PACKAGE__->wing_fields(
    name           => {
       dbic                => { data_type => 'varchar', size => 60, is_nullable => 0 },
       view                => 'public',
       edit                => 'required',
    },
    description    => {
        dbic                => { data_type => 'mediumtext', is_nullable => 1 },
        view                => 'public',
        edit                => 'postable',
    },
);

__PACKAGE__->wing_finalize_class( table_name => 'wikis');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

