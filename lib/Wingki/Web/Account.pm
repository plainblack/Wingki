package Wing::Web::Account;

use Dancer ':syntax';
use Wing::Perl;
use Ouch;
use Wing;
use Wing::Web;
use Wing::SSO;
use String::Random qw(random_string);
use Facebook::Graph;

get '/login' => sub {
    template 'account/login';
};

post '/login' => sub {
    return template 'account/login', { status_message => 'You must specify a username or email address.'} unless params->{login};
    return template 'account/login', { status_message => 'You must specify a password.'} unless params->{password};
    my $user = site_db()->resultset('User')->search({username => params->{login}},{rows=>1})->single;
    unless (defined $user) {
        $user = site_db()->resultset('User')->search({email => params->{login}},{rows=>1})->single;
        return template 'account/login', { status_message => 'User not found.'} unless defined $user;
    }

    # validate password
    if ($user->is_password_valid(params->{password})) {
        return login($user);
    }
    template 'account/login', { status_message => 'Password incorrect.'};
};

any '/logout' => sub {
    my $session = get_session();
    if (defined $session) {
        $session->end;
    }
    #session->destroy; #enable if we start using dancer sessions
    return redirect params->{redirect_after} || '/account';
};

get '/account/apikeys' => sub {
    my $user = get_user_by_session_id();
    my $api_keys = $user->api_keys;
    template 'account/apikeys', {current_user => describe($user, $user), page_title => 'API Keys', apikeys => format_list($api_keys, };
};

post '/account/apikey' => sub {
    my $current_user = get_user_by_session_id();
    my $status_message = 'Created successfully.';
    my $object = site_db()->resultset('APIKey')->new({});
    $object->user($current_user);
    my %params = params;
    eval {
        $object->verify_creation_params(\%params, $current_user);
        $object->verify_posted_params(\%params, $current_user);
    };
    if (hug) {
        $status_message = bleep;
    }
    else {
        $object->private_key(random_string('ssssssssssssssssssssssssssssssssssss'));
        $object->insert;
    }
    return redirect '/account/apikeys?status_message='.$status_message;
};

get '/account/apikey/:id' => sub {
    my $current_user = get_user_by_session_id();
    my $api_key = fetch_object('APIKey');
    $api_key->can_use($current_user);
    template 'account/apikey', { current_user => describe($current_user, $current_user), page_title => 'Manage API Key', apikey => describe($api_key, $current_user, };
};

del '/account/apikey/:id' => sub {
    my $current_user = get_user_by_session_id();
    my $api_key = fetch_object('APIKey');
    $api_key->can_use($current_user);
    $api_key->delete;
    redirect '/account/apikeys';
};


post '/account/apikey/:id' => sub {
    my $current_user = get_user_by_session_id();
    my $object = fetch_object('APIKey');
    $object->can_use($current_user);
    my $status_message = 'Updated successfully.';
    my %params = params;
    eval {
        $object->verify_posted_params(\%params, $current_user);
    };
    if (hug) {
        $status_message = bleep;
        return redirect '/account/apikey/'.$object->id.'?status_message='.$status_message;
    }
    else {
        $object->update;
        return redirect '/account/apikeys?status_message='.$status_message;
    }
};

get '/account' => sub {
    my $user = get_user_by_session_id();
    template 'account/index', { current_user => describe($user, $user), page_title => 'Account', };
};

post '/account' => sub {
    my $user = get_user_by_session_id();
    my $status_message = 'Updated successfully.';
    my %params = params;
    eval {
        $user->verify_posted_params(\%params, $user);
        if (params->{password1}) {
            if (params->{password1} eq params->{password2}) {
                $user->encrypt_and_set_password(params->{password1});
            }
            else {
                ouch 442, 'The passwords you typed do not match.', 'password';
            }
        }
    };
    if ($@) {
        $status_message = bleep;
    }
    else {
        $user->update;
    }
    redirect '/account?status_message='.$status_message;
};

post '/account/create' => sub {
    my $status_message = 'Created successfully.';
    my %params = params;
    my $user = site_db()->resultset('User')->new({});
    eval {
        $user->verify_creation_params(\%params, $user);
        $user->verify_posted_params(\%params, $user);
        if (params->{password1} eq params->{password2}) {
            $user->encrypt_and_set_password(params->{password1});
        }
        else {
            ouch 442, 'The passwords you typed do not match.', 'password';
        }
    };
    if ($@) {
        return template 'account/login', { status_message => bleep };
    }
    $user->insert;
    return login($user);
};

get '/account/reset-password' => sub {
    template 'account/reset-password';
};

post '/account/reset-password' => sub {
    return template 'account/reset-password', {status_message => 'You must supply an email address or username.'} unless params->{login};
    my $user = site_db()->resultset('User')->search({username => params->{login}},{rows=>1})->single;
    unless (defined $user) {
        $user = site_db()->resultset('User')->search({email => params->{login}},{rows=>1})->single;
        return template 'account/reset-password', {status_message => 'User not found.'} unless defined $user;
    }

    # validate password
    if ($user->email) {
        my $code = random_string('ssssssssssssssssssssssssssssssssssss');
        Wing->cache->set('password_reset'.$code, $user->id, 60 * 60 * 24);
        $user->send_templated_email(
            'reset_password',
            {
                code        => $code,
            }
        );
        return redirect '/account/reset-password-code';
    }
    return template 'account/reset-password', {status_message => 'That account has no email address associated with it.'};
};

get '/account/reset-password-code' => sub {
    template 'account/reset-password-code';
};

post '/account/reset-password-code' => sub {
    return template 'account/reset-password-code', {status_message => 'You must supply a reset code.'} unless params->{code};
    return template 'account/reset-password-code', {status_message => 'You must supply a new password.'} unless params->{password1};
    if (params->{password1} ne params->{password2}) {
        return template 'account/reset-password-code', {status_message => 'The passwords you typed do not match.'};
    }

    my $user_id = Wing->cache->get('password_reset'.params->{code});
    unless ($user_id) {
        return template 'account/reset-password-code', {status_message => 'That is an invalid code.'};
    }
    my $user = site_db()->resultset('User')->find($user_id);
    unless (defined $user) {
        return template 'account/reset-password-code', {status_message => 'The user attached to that code no longer exists.'};
    }
    $user->encrypt_and_set_password(params->{password1});
    return login($user);
};

get '/sso' => sub {
    my $user = eval{ get_user_by_session_id() };
    unless (params->{api_key_id}) {
        ouch 441, 'api_key_id is required.', 'api_key_id';
    }
    unless (params->{postback_uri}) {
        ouch 441, 'postback_uri is required.', 'postback_uri';
    }
    my $api_key = site_db()->resultset('APIKey')->find(params->{api_key_id});
    unless (defined $api_key) {
        ouch 440, 'API Key not found.', 'api_key_id';
    }
    my $permissions = params->{permission};
    unless (ref $permissions eq 'ARRAY') {
        $permissions = [$permissions];
    }
    my $sso = Wing::SSO->new(
        api_key_id              => $api_key->id,
        ip_address              => request->remote_address,
        postback_uri            => params->{postback_uri},
        requested_permissions   => $permissions,
        db                      => site_db(),
    )->store;
    if (defined $user) {
        $sso->user_id($user->id);
        $sso->store;
        if ($sso->has_requested_permissions) {
            return redirect $sso->redirect;
        }
        else {
            return redirect '/sso/authorize?sso_id='.$sso->id;
        }
    }
    template 'account/login', {sso_id => $sso->id};
};

get '/sso/authorize' => sub {
    my $user = get_user_by_session_id();
    my $sso = Wing::SSO->new(id => params->{sso_id}, db => site_db());
    ouch(401, 'User does not match SSO token.') unless $user->id eq $sso->user_id;
    template 'account/authorize', {
        current_user            => describe($user, $user),
        page_title              => $sso->api_key->name.' Wants Access',
        sso_id                  => $sso->id,
        requested_permissions   => $sso->requested_permissions,
        api_key                 => $sso->api_key->describe,
    };
};

post '/sso/authorize' => sub {
    my $user = get_user_by_session_id();
    my $sso = Wing::SSO->new(id => params->{sso_id}, db => site_db());
    $sso->grant_requested_permissions;
    return redirect $sso->redirect;
};

get '/sso/success' => sub {
    my $user = get_user_by_session_id();
    template 'account/ssosuccess', {
        current_user            => describe($user, $user),
        page_title              => 'Single Sign On Success',
    };    
};

get '/account/facebook' => sub {
    if (params->{sso_id}) {
        set_cookie sso_id  => params->{sso_id};
    }
    if (params->{redirect_after}) {
        set_cookie redirect_after  => params->{redirect_after};
    }
    redirect facebook()->authorize->extend_permissions(qw(email))->uri_as_string;
};

get '/account/facebook/postback' => sub {
    my $fb = facebook();
    $fb->request_access_token(params->{code});
    my $fbuser = $fb->query->find('me')->request->as_hashref;

    unless (exists $fbuser->{id}) {
        ouch 451, 'Could not authenticate your Facebook account.';
    }
    
    my $users = site_db()->resultset('User');
    my $user = $users->search({facebook_uid => $fbuser->{id} }, { rows => 1 })->single;
    if (defined $user) {
        $user->email($fbuser->{email}); # update their email in case it's changed
        $user->update;
    }
    else {
        $user = $users->search({email => $fbuser->{email} }, { rows => 1 })->single;
        if (defined $user) { # an account with that email already exists, let's link it to facebook
            $user->facebook_uid($fbuser->{id});
            $user->update;
        }
        else { # create a new account
            $user = $users->new({});
            $user->facebook_uid($fbuser->{id});
            $user->real_name($fbuser->{name});
            $user->email($fbuser->{email});
            $user->username($fbuser->{email});
            $user->insert;
        }
    }
    return login($user);
};

get '/account/profile/:id' => sub {
    my $current_user = eval{get_user_by_session_id()};
    my $user = fetch_object('User');
    template 'account/profile', {
        current_user    => describe($current_user, $current_user),
        page_title      => 'Profile for '.$user->display_name,
        profile_user    => describe($user, $current_user),
        reviews         => format_list(scalar $user->reviews->search(undef, {order_by => { -desc => 'date_created' }}), include_related_objects => 1),
        designers       => format_list(scalar $user->designers->search(undef, {order_by => 'name'})),
    };
};

sub login {
    my ($user) = @_;
    my $session = $user->start_session({ api_key_id => Wing->config->get('default_api_key'), ip_address => request->remote_address });
    set_cookie session_id   => $session->id,
                expires     => '+5y',
                http_only   => 0,
                path        => '/';
    if (params->{sso_id}) {
        my $cookie = cookies->{sso_id};
        my $sso_id = $cookie->value if defined $cookie;
        $sso_id ||= params->{sso_id};
        my $sso = Wing::SSO->new(id => $sso_id, db => site_db());
        $sso->user_id($user->id);
        $sso->store;
        if ($sso->has_requested_permissions) {
            return redirect $sso->redirect;
        }
        else {
            return redirect '/sso/authorize?sso_id='.$sso->id;
        }
    }
    my $cookie = cookies->{redirect_after};
    my $uri = $cookie->value if defined $cookie;
    $uri ||= params->{redirect_after} || '/account';
    return redirect $uri;
}

sub facebook {
    return Facebook::Graph->new(Wing->config->get('facebook'));
}


true;
