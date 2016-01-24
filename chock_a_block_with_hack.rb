
require 'httparty'
require 'json'

class Trader


  @@base_url = "https://api.stockfighter.io/ob/api"


  def initialize(apikey,venue,stock,account,instance)

    @apikey = apikey
    @venue = venue
    @stock = stock
    @account = account
    @instance = instance

  end


  # The method takes a lower and higher limit and
  # use them to generate a random quantity for every order
  def exec_orders(lower, higher)

    # get the target price

    target = get_target

    unless target
      return "program exited"
    end

    #set the order hash
    order = {
      "account" => @account,
      "venue" => @venue,
      "symbol" => @stock,
      "price" => target,
      "direction" => "buy",
      "orderType" => "limit"
    }


    # place orders until the target quantity is reached
    while (quantity ||= 1) < 100000

      # generate a random quantity for the order
      order["qty"] = rand(lower..higher)

      #execute the order
      response = HTTParty.post("#{@@base_url}/venues/#{@venue}/stocks/#{@stock}/orders",
                               :body => JSON.dump(order),
                               :headers => {"X-Starfighter-Authorization" => @apikey}
                               )

      # check that the order has been submited correctly
      case response.code

      # order has been placed
      when 200


        # get the status of the order
        id = response.parsed_response["id"]

        response = HTTParty.get("#{@@base_url}/venues/#{@venue}/stocks/#{@stock}/orders/#{id}",
                                :headers => {"X-Starfighter-Authorization" => @apikey})

        status = response.parsed_response["open"]

        # check the status of the order 3 times, if it's still open after 3 times
        # close the order and accept the partial fill
        while status

          count ||= 0

          response = HTTParty.get("#{@@base_url}/venues/#{@venue}/stocks/#{@stock}/orders/#{id}",
                                  :headers => {"X-Starfighter-Authorization" => @apikey})

          status = response.parsed_response["open"]

          puts "The order #{id} is still open"

          count += 1
          #order has been checked 3 times
          if count.equal?(3)
            # close the order
            response = HTTParty.delete("#{@@base_url}/venues/#{@venue}/stocks/#{@stock}/orders/#{id}",
                                      :headers => {"X-Starfighter-Authorization" => @apikey})

            count = 0

            break

          end

        end

        puts "The order #{id} is closed"

        #update the quantity
        quantity += response.parsed_response["totalFilled"].to_i

        puts "Total quantity: #{quantity}"




      # Order has not been placed
      else

        puts response

      end

    end

    puts "#{quantity} stocks has been ordered"

  end

  private

    # Get the target price set by the risk desk by catching flash message in the UI
    def get_target


      # get the price for the last trade
      response = HTTParty.get("#{@@base_url}/venues/#{@venue}/stocks/#{@stock}/quote")

      last = response.parsed_response["last"].to_i

      #set the limit for the first offer as one dollar less than the last price
      limit = last - 100

      # Order parameters hash
      order = {
        "account" => @account,
        "venue" => @venue,
        "symbol" => @stock,
        "price" => limit,
        "qty" => 1,
        "direction" => "buy",
        "orderType" => "limit"
      }

      #make the first offer to activate the flash message in the UI
      response = HTTParty.post("#{@@base_url}/venues/#{@venue}/stocks/#{@stock}/orders",
                                 :body => JSON.dump(order),
                                 :headers => {"X-Starfighter-Authorization" => @apikey}
                                 )


      # wait untill the order is closed
      id = response.parsed_response["id"]

      status = response.parsed_response["open"]

      while status

        response = HTTParty.get("#{@@base_url}/venues/#{@venue}/stocks/#{@stock}/orders/#{id}",
                                :headers => {"X-Starfighter-Authorization" => @apikey})

        status = response.parsed_response["open"]


      end

      # wait a few seconds for the message in the UI to be generated
      sleep(5)

      # catch the treshold from the message in the UI
      response = HTTParty.get("https://www.stockfighter.io/gm/instances/#{@instance}",
                              :headers => {"X-Starfighter-Authorization" => @apikey})

      flash_message = response.parsed_response["flash"]["info"]


      regex = /\d\d\.\d\d\.$/

      threshold = regex.match(flash_message).to_s.chop.to_f

      unless threshold

        puts "There has been a problem getting the target price"

        nil

      end

      puts "Target price has been fetched"

      (threshold * 100).to_i

    end

end




file = File.read('config.json')

config = JSON.parse(file)

t = Trader.new(config["apikey"],config["venue"],config["stock"],config["account"],config["instance"])


t.exec_orders(100, 500)