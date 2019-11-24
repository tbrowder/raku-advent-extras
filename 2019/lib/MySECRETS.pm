package MySECRETS;

use Readonly;

# keep my secrets

# gmail
Readonly our $username => '';
Readonly our $password => '';

# twitter
# twitter user account;
Readonly our $tuser               => '';
# twitter user's credentials (read and write):
Readonly our $consumer_key        => '';
Readonly our $consumer_secret     => '';
Readonly our $access_token        => '';
Readonly our $access_token_secret => '';

# mandatory true return for modules
1;
