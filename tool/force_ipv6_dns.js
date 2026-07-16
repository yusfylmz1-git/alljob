// Windows resolver bazen googleapis A kaydını reddeder (EREFUSED) ve
// getaddrinfo ENOTFOUND verir; AAAA ise çalışır. firebase-tools fetch
// yolunu IPv6'ya zorla (yalnız bu preload ile).
'use strict';
const dns = require('dns');
const origLookup = dns.lookup.bind(dns);

function shouldForceV6(hostname) {
  if (!hostname || typeof hostname !== 'string') return false;
  return hostname.endsWith('.googleapis.com') ||
    hostname.endsWith('.google.com') ||
    hostname === 'firebase.google.com';
}

dns.lookup = function lookup(hostname, options, callback) {
  if (typeof options === 'function') {
    callback = options;
    options = {};
  } else if (typeof options === 'number') {
    options = {family: options};
  } else {
    options = options || {};
  }
  if (shouldForceV6(hostname) && options.family !== 4) {
    return origLookup(hostname, {...options, family: 6}, callback);
  }
  return origLookup(hostname, options, callback);
};

console.error('[force_ipv6_dns] googleapis → family 6');
