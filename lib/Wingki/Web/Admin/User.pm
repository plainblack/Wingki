package Wingki::Web::Admin::User;

use Dancer ':syntax';
use Wing::Perl;
use Ouch;
use Wing;
use Wing::Web;

get '/admin/users' => sub {
    my $user = get_admin_by_session_id();
    my $users = site_db()->resultset('User');
    if (params->{do_the_search}) {
        $users = $users->search({ -or => {username => { like => params->{query}.'%'}, email => { like => params->{query}.'%'} }});
    }
    else {
        $users = $users->search({id => 'none'}); # don't bother showing anything if they haven't searched
    }
    template 'admin/users', { current_user => describe($user), page_title => 'Users', users => format_list($users)};
};

post '/admin/user' => sub {
    my $current_user = get_admin_by_session_id();
    my $status_message = 'Created successfully.';
    my $object = site_db()->resultset('User')->new({});
    my %params = params;
    eval {
        $object->verify_creation_params(\%params, $current_user);
        $object->verify_posted_params(\%params, $current_user);
    };
    if ($@) {
        $status_message = bleep;
    }
    else {
        $object->insert;
    }
    return redirect '/admin/users?status_message='.$status_message;
};

get '/admin/user/:id' => sub {
    my $current_user = get_admin_by_session_id();
    template 'admin/user', { current_user => $current_user, page_title => 'Edit User', user => describe(fetch_object('User'), $current_user)};
};

post '/admin/user/:id' => sub {
    my $current_user = get_admin_by_session_id();
    my $object = fetch_object('User');
    my $status_message = 'Updated successfully.';
    my %params = params;
    eval {
        $object->verify_creation_params(\%params, $current_user);
        $object->verify_posted_params(\%params, $current_user);
        if (params->{password1}) {
            if (params->{password1} eq params->{password2}) {
                $object->encrypt_and_set_password(params->{password1});
            }
            else {
                ouch 442, 'The passwords you typed do not match.', 'password';
            }
        }
    };
    if ($@) {
        $status_message = bleep;
        template 'admin/user', { current_user => $current_user, page_title => 'Edit User', user => describe(fetch_object('User'), $current_user)};
    }
    else {
        $object->update;
        return redirect '/admin/users?status_message='.$status_message;
    }
};


post '/admin/user/:id/become' => sub {
    my $current_user = get_admin_by_session_id();
    my $object = fetch_object('User');
    my $session = $current_user->current_session;
    $session->user_id($object->id);
    $session->extend;
    set_cookie session_id   => $session->id,
                expires     => '+5y',
                http_only   => 0,
                path        => '/';
    return redirect '/account';
};

true;
