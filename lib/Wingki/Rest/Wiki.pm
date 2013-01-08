package Wingki::Rest::Wiki;

use Wing::Perl;
use Wing;
use Dancer;
use Wing::Rest; 

get '/api/wiki' => sub {
    my $user = get_user_by_session_id();
    my $data = site_db()->resultset('Wiki')->search(undef,{order_by => 'name'});
    return format_list($data); 
};

generate_crud('Wiki');

1;
