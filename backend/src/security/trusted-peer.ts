import { IncomingMessage } from 'node:http';
import { ENV } from '../config/env';

// Express already depends on proxy-addr. Reuse its CIDR-aware trust rules for HTTP upgrades.
const proxyAddress = require('proxy-addr') as {
  (req: IncomingMessage, trust: (address: string, index: number) => boolean): string;
  compile(ranges: string[]): (address: string, index: number) => boolean;
};
export const trustedProxy = ENV.TRUST_PROXY
  ? proxyAddress.compile(ENV.TRUST_PROXY.split(',').map(value => value.trim()))
  : () => false;
export const trustedPeer = (req: IncomingMessage): string => proxyAddress(req, trustedProxy);
