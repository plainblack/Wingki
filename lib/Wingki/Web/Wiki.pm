package TGC::Web::Wiki;

use Dancer ':syntax';
use Wing::Perl;
use Ouch;
use Wing;
use Wing::Web;

get '/' => sub {
    my $user = get_user_by_session_id();
    my $pages = site_db->resultset('Wiki')->search();
    template 'index', { current_user => describe($user), pages => format_list($pages) };
};

post '/wiki' => sub {
    my $current_user = get_user_by_session_id();
    my $status_message = 'Created successfully.';
    my $object = site_db()->resultset('Wiki')->new({});
    my $params = params();
    eval {
        $object->verify_creation_params($params, $current_user);
        $object->verify_posted_params($params, $current_user);
    };
    if (hug) {
        $status_message = bleep;
        return redirect '/?status_message='.$status_message;
    }
    else {
        $object->insert;
        return redirect '/wiki/'.$object->id.'?status_message='.$status_message;
    }
};

get '/wiki/:id' => sub {
    my $current_user = get_user_by_session_id();
    my $object = fetch_object('Wiki');
    $object->can_use($current_user);
    my $vars = $object->describe;
    template 'wiki/view', $vars;
};

put '/wiki/:id' => sub {
    my $current_user = get_user_by_session_id();
    my $object = fetch_object('Wiki');
    $object->can_use($current_user);
    $object->update({param()});
    return redirect '/wiki/'.$object->id;
};

del '/wiki/:id' => sub {
    my $current_user = get_user_by_session_id();
    my $object = fetch_object('Wiki');
    $object->can_use($current_user);
    $object->delete;
    return redirect '/';
};

true;
