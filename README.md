# DMARC Analyzer

This is my personal implementation of a parser for DMARC to alert me when a report comes back with problems. Feel free to adapt it to your needs if necessary.

## Setting Up Automatic Analysis with Postfix

The following won't necessary work command for command, but should give you enough information about what is necessary.

### Building
First you have to clone and build the binary:

    sudo git clone https://github.com/drewag/dmarc-analyzer.git /etc/postfix/dmarc-analyzer
    cd /etc/postfix/dmarc-analyzer
    swift package update
    swift build -c release
    sudo chmod 777 -R .
    
Then you have to setup the options file:

### Configure Options
Create /etc/postfix/dmarc-analyzer/dmarc-options.json
    
    {
        "sourceEmail": "dmarc-analyzer@example.com",
        "problemEmail": "dmarc@example.com",
        "approvedServers": [
            "12.345.67.89",
            "2600:0000::0000:0000:0000:0000",
        ]
    }
    
List as many approved server IP addresses as necessary.

### Configure Postfix

First, add an alias to feed into the binary: /etc/aliases

    dmarcanalyzer:   "|/etc/postfix/dmarc-analyzer/.build/release/analyze /etc/postfix/dmarc-analyzer/dmarc-options.json"
    
Then refresh the aliases

    sudo newaliases

Then you have to setup a virtual alias:

    aggrep@example.com dmarcanalyzer@localhost.example.com
    
Then postmap that file

    sudo postmap /etc/postfix/virtual
    
Finally reload postfix

    sudo postfix reload
