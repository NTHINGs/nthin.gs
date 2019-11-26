import sys
from godaddypy import Client, Account

try:
    nameservers = sys.argv[1].split(',')

    domain_name = sys.argv[2]

    my_acct = Account(api_key=sys.argv[3].split(':')[0], api_secret=sys.argv[3].split(':')[1])
    client = Client(my_acct)
    client.update_domain(domain_name, nameServers=nameservers)
except:
    sys.exit(0)