class MailCatcher::DeliveryService
  attr_reader :message

  mattr_accessor :address
  mattr_accessor :port
  mattr_accessor :domain
  mattr_accessor :user_name
  mattr_accessor :password
  mattr_accessor :recipient

  mattr_accessor :authentication # authentication is currently hard-coded
  @@authentication = 'login'

  def initialize(message)
    @message = message
  end

  def config
    self.class
  end

  def deliver!(recipient = config.recipient, via = :localhost)
    config_hash = delivery_config(via)

    puts "==> Opening connection to: #{config_hash}"

    Net::SMTP.start(
      config_hash[:address],
      config_hash[:port],
      config_hash[:username],
      config_hash[:password],
      :plain) do |client|

      client.send_message(
        message['source'],
        config.email,
        recipient || message['recipients']
      )
    end
  end

  private

  def delivery_config(via = :localhost)
    case via
    when :localhost
      localhost_config
    when :dyn
      env_config
    else
      localhost_config
    end
  end

  def localhost_config
    {
      address: "127.0.0.1",
      port: 25,
      username: "",
      password: ""
    }
  end

  def env_config
    {
      address: config.address,
      port: config.port,
      username: config.user_name,
      password: config.password
    }
  end

  class << self
    def configure(options = {})
      @@address = options[:delivery_address]
      @@port = options[:delivery_port]
      @@domain = options[:delivery_domain]
      @@user_name = options[:delivery_user_name]
      @@password = options[:delivery_password]
      @@recipient = options[:delivery_recipient]
    end
  end
end
