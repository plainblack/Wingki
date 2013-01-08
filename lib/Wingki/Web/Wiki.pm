package Wingki::Web::Wiki;

use Dancer ':syntax';
use Wing::Perl;
use Ouch;
use Wing;
use Wing::Web;

get '/' => sub {
    my $user = get_user_by_session_id();
    template 'index', { current_user => describe($user) };
};

post '/wiki' => sub {
    my $current_user = get_user_by_session_id();
    my $object = site_db()->resultset('Wiki')->new({});
    my %params = params;
    eval {
        $object->verify_creation_params(\%params, $current_user);
        $object->verify_posted_params(\%params, $current_user);
    };
    if (hug) {
        return redirect '/?error_message='.bleep;
    }
    else {
        $object->insert;
        return redirect '/wiki/'.$object->uri_part.'?success_message=Created succssfully.';
    }
};

get '/wiki/:uri_part' => sub {
    my $current_user = get_user_by_session_id();
    Wing->log->warn("uri_part: ".params->{uri_part});
    my $wiki = site_db()->resultset('Wiki')->search({ uri_part => params->{uri_part}},{rows => 1})->single;
    unless (defined $wiki) {
        ouch 404, 'Wiki page not found.';
    }
    $wiki->can_use($current_user);
    template 'wiki/view', {
        current_user => describe($current_user),
        wiki         => describe($wiki),
    };
};

put '/wiki/:id' => sub {
    my $current_user = get_user_by_session_id();
    my $object = fetch_object('Wiki');
    $object->can_use($current_user);
    my %params = params;
    eval {
        $object->verify_posted_params(\%params, $current_user);
    };
    if (hug) {
        return redirect '/?error_message='.bleep;
    }
    else {
        $object->update;
        return redirect '/wiki/'.$object->uri_part.'?success_message=Updated succssfully.';
    }
    return redirect '/wiki/'.$object->uri_part;
};

del '/wiki/:id' => sub {
    my $current_user = get_user_by_session_id();
    my $object = fetch_object('Wiki');
    $object->can_use($current_user);
    $object->delete;
    return redirect '/';
};

true;
