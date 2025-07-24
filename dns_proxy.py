#!/usr/bin/env python3

import sys
import socket
import threading
from datetime import datetime
from dnslib import DNSRecord, QTYPE, RCODE
from dnslib.server import DNSServer

class WhitelistDNSResolver:
    def __init__(self, whitelist_file, upstream_dns="8.8.8.8"):
        self.upstream_dns = upstream_dns
        self.whitelist = self.load_whitelist(whitelist_file)
        print(f"[{datetime.now().isoformat()}] DNS proxy started with {len(self.whitelist)} whitelisted domains")
        sys.stdout.flush()
    
    def load_whitelist(self, whitelist_file):
        try:
            with open(whitelist_file, 'r') as f:
                domains = [line.strip() for line in f if line.strip() and not line.startswith('#')]
            return set(domains)
        except FileNotFoundError:
            print(f"[{datetime.now().isoformat()}] ERROR: Whitelist file {whitelist_file} not found")
            sys.stdout.flush()
            return set()
    
    def resolve(self, request, handler):
        reply = request.reply()
        qname = str(request.q.qname).rstrip('.')
        
        if qname in self.whitelist:
            print(f"[{datetime.now().isoformat()}] ALLOWED: {qname}")
            sys.stdout.flush()
            
            try:
                # Forward request to upstream DNS server
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                sock.settimeout(5)
                sock.sendto(request.pack(), (self.upstream_dns, 53))
                data, _ = sock.recvfrom(1024)
                sock.close()
                
                # Parse upstream response and return it
                upstream_reply = DNSRecord.parse(data)
                return upstream_reply
            except Exception as e:
                print(f"[{datetime.now().isoformat()}] ERROR forwarding {qname}: {e}")
                sys.stdout.flush()
                reply.header.rcode = RCODE.SERVFAIL
        else:
            print(f"[{datetime.now().isoformat()}] BLOCKED: {qname}")
            sys.stdout.flush()
            reply.header.rcode = RCODE.NXDOMAIN
        
        return reply

if __name__ == "__main__":
    resolver = WhitelistDNSResolver("/data/whitelist.txt")
    server = DNSServer(resolver, port=53, address="0.0.0.0")
    
    try:
        server.start_thread()
        print(f"[{datetime.now().isoformat()}] DNS server listening on port 53")
        sys.stdout.flush()
        
        # Keep the main thread alive
        while True:
            threading.Event().wait(1)
    except KeyboardInterrupt:
        print(f"[{datetime.now().isoformat()}] DNS server shutting down")
        sys.stdout.flush()
        server.stop()
    except Exception as e:
        print(f"[{datetime.now().isoformat()}] ERROR: {e}")
        sys.stdout.flush()
        sys.exit(1)