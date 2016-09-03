package DDG::Spice::SkyscannerFlightSearch;

# ABSTRACT: This IA will call Skyscanner's API to retrieve the cheapest flight prices to 
# different countries from the user's country

use DDG::Spice;
use strict;
use warnings;
use JSON;

# No caching of results
spice is_cached => 0;

spice wrap_jsonp_callback => 1; # only enable for non-JSONP APIs (i.e. no &callback= parameter)

spice from => '([^/]*)/([^/]*)/([^/]*)/([^/]*)/([^/]*)';
spice to => 'http://partners.api.skyscanner.net/apiservices/browseroutes/v1.0/$1/$3/$2/$4/$5/anytime/anytime?apikey={{ENV{DDG_SPICE_SKYSCANNER_APIKEY}}}';
spice alt_to => {
    skyscanner_images => {
        to => 'https://gateway.skyscanner.net/travel-api/v1/entities?external_ids=$1&enhancers=images&apikey={{ENV{DDG_SPICE_SKYSCANNER_IMAGES_APIKEY}}}'
    }
};

triggers startend => 'skyscanner';

# Load the list of currencies for each market
my $currencies_raw = share('currencyCountryMapping.json')->slurp;
my $currencies = decode_json($currencies_raw);

# Load the list of countries and their ISO code
my $countries_raw = share('countryIsoCodes.json')->slurp;
my $countries = decode_json($countries_raw);

# Load the list of cities and their Skyscanner code (using Skyscanner code as IATA code is ambiguous in certain cases such as Berlin where the city 
# and one of the airports have the same code)
my $cities_raw = share('citySkyscannerCodes.json')->slurp;
my $cities = decode_json($cities_raw);

# Handle statement
handle remainder => sub {
    my $origin = "";
    my $destination = "";
    
    # get user's location for the market if available (airline and travel agent prices depend on the market), if none default to 'US'
    my $market = $loc->country_code;
    if ($market eq "") {
        $market = "US";
    }
        
    # get language locale (replace DDG's '_' with '-' for Skyscanner compatibility), if none default to 'en-US'
    my $locale = $lang->locale;
    $locale =~ tr/_/-/;
    if ($locale eq "") {
        $locale = "en-US";
    }   
    
    # get currency from the json file using the market, if none default to USD
    my $currency = $currencies->{$market};
    if ($currency eq "") {
        $currency = "USD";
    }
    
    print "\n\nMarket: " . $market;
    print "\nCurrency: " . $currency . "\n\n";

    # query must be in the form 
    # [from][origin][to][destination]
    # or [origin][to][destination]
    # or [from][origin]
    # or [destination]
    # 
    my @query = split(/\s+to\s+/, $_);
    # strip 'flight(s) from' to allow more flexible queries and remove left trailing space
    $query[0] =~ s/\b(flight(?:s)?|from)\b//g;
    $query[0] =~ s/^\s+//;
    #print "\n\n**** User query *****";
    #print "\nOrigin: " . $query[0];
    #print "\nDestination: " . $query[1];
    #print "\n*********************\n\n";

    # determine origin country or city (use lowercase), if no match use user's country
    $origin = lc($query[0]);
    if ($origin eq "") {
        $origin = $market;
    } else {
        if (exists $countries->{$origin}) {
            $origin = $countries->{$origin};
        } elsif (exists $cities->{$origin}) {
            $origin = $cities->{$origin};
        } else {
            $origin = $market;
        }
    } 
    
    # determine destination country or city (use lowercase), if no match use 'anywhere'
    $destination = lc($query[1]);
    if ($destination eq "") {
        $destination = "anywhere";
    } else {
        if (exists $countries->{$destination}) {
            $destination = $countries->{$destination};
        } elsif (exists $cities->{$destination}) {
            $destination = $cities->{$destination};
        } else {
            $destination = "anywhere";
        }
    } 
    
    return $market, $locale, $currency, $origin, $destination;
    return;
};

1;
