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

# Btc.com API.
#
# Here: https://btc.com/api-doc
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2020 Yegor Bugayenko
# License:: MIT
class Sibit
  # Btc.com API.
  class Btc
    # Constructor.
    def initialize(log: Sibit::Log.new, http: Sibit::Http.new, dry: false)
      @http = http
      @log = log
      @dry = dry
    end

    # Current price of BTC in USD (float returned).
    def price(_currency = 'USD')
      raise Sibit::NotSupportedError, 'Btc.com API doesn\'t provide prices'
    end

    # Gets the balance of the address, in satoshi.
    def balance(address)
      uri = URI("https://chain.api.btc.com/v3/address/#{address}/unspent")
      json = Sibit::Json.new(http: @http, log: @log).get(uri)
      if json['err_no'] == 1
        @log.info("The balance of #{address} is zero (not found)")
        return 0
      end
      txns = json['data']['list']
      balance = txns.map { |tx| tx['value'] }.inject(&:+) || 0
      @log.info("The balance of #{address} is #{balance}, total txns: #{txns.count}")
      balance
    end

    # Get hash of the block after this one.
    def next_of(hash)
      head = Sibit::Json.new(http: @http, log: @log).get(
        URI("https://chain.api.btc.com/v3/block/#{hash}")
      )
      nxt = head['data']['next_block_hash']
      nxt = nil if nxt == '0000000000000000000000000000000000000000000000000000000000000000'
      @log.info("The next block of #{hash} is #{nxt}")
      nxt
    end

    # The height of the block.
    def height(hash)
      json = Sibit::Json.new(http: @http, log: @log).get(
        URI("https://chain.api.btc.com/v3/block/#{hash}")
      )
      h = json['data']['height']
      @log.info("The height of #{hash} is #{h}")
      h
    end

    # Get recommended fees, in satoshi per byte.
    def fees
      raise Sibit::NotSupportedError, 'Btc.com doesn\'t provide recommended fees'
    end

    # Gets the hash of the latest block.
    def latest
      uri = URI('https://chain.api.btc.com/v3/block/latest')
      json = Sibit::Json.new(http: @http, log: @log).get(uri)
      hash = json['data']['hash']
      @log.info("The hash of the latest block is #{hash}")
      hash
    end

    # Fetch all unspent outputs per address.
    def utxos(sources)
      txns = []
      sources.each do |hash|
        json = Sibit::Json.new(http: @http, log: @log).get(
          URI("https://chain.api.btc.com/v3/address/#{hash}/unspent")
        )
        json['data']['list'].each do |u|
          outs = Sibit::Json.new(http: @http, log: @log).get(
            URI("https://chain.api.btc.com/v3/tx/#{u['tx_hash']}?verbose=3")
          )['data']['outputs']
          outs.each_with_index do |o, i|
            next unless o['addresses'].include?(hash)
            txns << {
              value: o['value'],
              hash: u['tx_hash'],
              index: i,
              confirmations: u['confirmations'],
              script: [o['script_hex']].pack('H*')
            }
          end
        end
      end
      txns
    end

    # Push this transaction (in hex format) to the network.
    def push(_hex)
      raise Sibit::NotSupportedError, 'Btc.com doesn\'t provide payment gateway'
    end

    # This method should fetch a Blockchain block and return as a hash.
    def block(hash)
      head = Sibit::Json.new(http: @http, log: @log).get(
        URI("https://chain.api.btc.com/v3/block/#{hash}")
      )
      nxt = head['data']['next_block_hash']
      nxt = nil if nxt == '0000000000000000000000000000000000000000000000000000000000000000'
      {
        hash: head['data']['hash'],
        orphan: head['data']['is_orphan'],
        next: nxt,
        previous: head['data']['prev_block_hash'],
        txns: txns(hash)
      }
    end

    private

    def txns(hash)
      page = 1
      psize = 50
      all = []
      loop do
        txns = Sibit::Json.new(http: @http, log: @log).get(
          URI("https://chain.api.btc.com/v3/block/#{hash}/tx?page=#{page}&pagesize=#{psize}")
        )['data']['list'].map do |t|
          {
            hash: t['hash'],
            outputs: t['outputs'].reject { |o| o['spent_by_tx'] }.map do |o|
              {
                address: o['addresses'][0],
                value: o['value']
              }
            end
          }
        end
        all += txns
        page += 1
        break if txns.length < psize
      end
      all
    end
  end
end
