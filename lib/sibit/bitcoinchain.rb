# frozen_string_literal: true

# Copyright (c) 2019-2020 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'uri'
require 'json'
require_relative 'version'
require_relative 'error'
require_relative 'log'
require_relative 'http'
require_relative 'json'

# Bitcoinchain.com API.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2020 Yegor Bugayenko
# License:: MIT
class Sibit
  # Btc.com API.
  class Bitcoinchain
    # Constructor.
    def initialize(log: Sibit::Log.new, http: Sibit::Http.new, dry: false)
      @http = http
      @log = log
      @dry = dry
    end

    # Current price of BTC in USD (float returned).
    def price(_currency)
      raise Sibit::Error, 'Not implemented yet'
    end

    # Gets the balance of the address, in satoshi.
    def balance(address)
      Sibit::Json.new(http: @http, log: @log).get(
        URI("https://api-r.bitcoinchain.com/v1/address/#{address}")
      )[0]['balance']
    end

    # Get recommended fees, in satoshi per byte.
    def fees
      raise Sibit::Error, 'Not implemented yet'
    end

    # Gets the hash of the latest block.
    def latest
      Sibit::Json.new(http: @http, log: @log).get(
        URI('https://api-r.bitcoinchain.com/v1/status')
      )['hash']
    end

    # Fetch all unspent outputs per address.
    def utxos(_sources)
      raise Sibit::Error, 'Not implemented yet'
    end

    # Push this transaction (in hex format) to the network.
    def push(_hex)
      raise Sibit::Error, 'Not implemented yet'
    end

    # This method should fetch a Blockchain block and return as a hash. Raises
    # an exception if the block is not found.
    def block(hash)
      head = Sibit::Json.new(http: @http, log: @log).get(
        URI("https://api-r.bitcoinchain.com/v1/block/#{hash}")
      )[0]
      raise Sibit::Error, "The block #{hash} is not found" if head.nil?
      nxt = head['next_block']
      nxt = nil if nxt == '0000000000000000000000000000000000000000000000000000000000000000'
      {
        hash: head['hash'],
        orphan: !head['is_main'],
        next: nxt,
        previous: head['prev_block'],
        txns: Sibit::Json.new(http: @http, log: @log).get(
          URI("https://api-r.bitcoinchain.com/v1/block/txs/#{hash}")
        )[0]['txs'].map do |t|
          {
            hash: t['self_hash'],
            outputs: t['outputs'].select { |o| o['spent'] }.map do |o|
              {
                address: o['receiver'],
                value: o['value']
              }
            end
          }
        end
      }
    end
  end
end