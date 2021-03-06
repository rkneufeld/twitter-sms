require 'rubygems'
require 'twitter'
require 'tlsmail'
require 'optparse'
require 'cgi'
require 'net/pop'
require 'rmail'

require 'logger.rb'

if RUBY_VERSION < "1.9"
  raise "Version too low. Please get Ruby 1.9"
end

module TwitterSms
  SEC_PER_HOUR = 3600 # Seconds per hour (don't like this...)

  # RMail doesn't like parsing body properly if there is a mistaken ' ' between body and header
  def self.space_stripper!(msg)
    msg.gsub!(/^\s+$/,'')
  end

  class Checker

    attr_reader :config

    def username
      @user['name']
    end

    def initialize(config_file="#{ENV['HOME']}/.twitter-sms.conf", args=ARGV)
      load_config(config_file)
      load_opts(args) # Loaded options are intended to overide defaults

      # Required for gmail smtp (and not a part of standalone Net::SMTP)
      Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
      Net::POP3.enable_ssl(OpenSSL::SSL::VERIFY_NONE) # maybe verify...
    end

    # Run the twitter-sms bot once or repeatedly, depending on config
    def run
      begin # do-while
        load_config if config_stale? unless @config['dont_refresh']

        receive_messages

        if @config['active']
          tweets = update
          send tweets unless tweets.nil?
        end

        if @config['keep_alive']
          putd "Waiting for ~#{@config['wait']/60.0} minutes..."
          Kernel.sleep @config['wait']
        end
      end while @config['keep_alive']
      tweets # Return the last set of tweets we get
    end

    # Collect a list of recent tweets on a user's timeline (that are not their own)
    def update
      twitter = Twitter::Base.new(@user['name'],@user['password'])

      begin
        if twitter.rate_limit_status.remaining_hits > 0
          now         = Time.now
          tweets      = twitter.timeline(:friends, :since => @last_check)
          @last_check = now
        else
          putd "Your account has run out of API calls; call not made."
        end
      rescue
        putd "Error occured retreiving timeline. Perhaps Internet is down?"
      end
      return tweets
    end

    def reduce_tweets(tweets)
      # Block own tweets if specified via settings
      tweets.reject! {|t| t.user.screen_name == @user['name']} unless @config['own_tweets']
      # Don't send messages from users under no_follow
      tweets.reject! {|t| @config['no_follow'].member?(t.user.screen_name) }
      tweets.reverse # reverse-chronological
    end

    # Email via Gmail SMTP any tweets to the desired cell phone
    def send(tweets)
      putd "Sending received tweets..."
      begin
        # Start smtp connection to provided bot email
        Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com',
                        @bot['email'], @bot['password'], :login) do |smtp|

          tweets.each do |tweet|
            smtp.send_message(content(tweet),@bot['email'],@user['phone']) rescue putd "Error occured sending message:"
            putd "\tSent: #{tweet.user.screen_name}: #{tweet.text[0..20]}..."
          end

        end
        putd "Messages sent."
      rescue
        putd "Error occured starting smtp. Perhaps account info is incorrect" +
          " or Internet is down?"
        putd "  Message was: #{$!}"
      end
    end

    def receive_messages
      Net::POP3.start('pop.gmail.com',995, @bot['email'], @bot['password']) do |pop|
        pop.each_mail do |mail|
          process_pop_message(mail.pop)
        end
      end
    end

    private

    # Put Debug (prepend time) if debug printouts turned on
    def putd (message)
      if @config['debug']
        if @config['log_to'] == 'file'
          @logger ||= TwitterSms::Logger.new("#{ENV['HOME']}/.twitter_sms-log")
          @logger.log(message)
        elsif @config['log_to'] == 'console'
          puts "#{Time.now.strftime("(%b %d - %H:%M:%S)")} #{message}"
        end
      else
        puts message
      end
    end

    # Verify syntax for dissecting pop message
    def process_pop_message(msg)
      TwitterSms::space_stripper!(msg) # Remove sometimes broken extra spaces
      r_msg = RMail::Parser.read(msg)

      #must be extracted before we reduce to plaintext
      from = r_msg.header.from[0].address

      plain = reduce_to_plaintext(r_msg)
      body = plain.body

      if from == @user['phone'] # must come from phone
        # Extract this log later
        if body =~ /^off\w*/i
          @config['active'] = false
          putd "Received command to disable texting"
        elsif body =~ /^on\w*/i
          @config['active'] = true
          putd "Received command to enable texting"
        else
          body.scan(/ignore (\w+)/i) {|_| @config['no_follow'] << $1 }
          body.scan(/follow (\w+)/i) {|_| @config['no_follow'] -= [$1] } # also set follow
        end
      end
    end

    # Sometimes Rmail messages are multipart, we only want plaintext
    #TEST?
    def reduce_to_plaintext(r_msg)
      if r_msg.multipart?
        r_msg = r_msg.body.find do |part|
          part.header.content_type == "text/plain"
        end
      else
        r_msg
      end
    end

    # Parse and store a config file (either as an initial load or as
    # an update)
    def load_config(config_file=@config_file['name'])
      loaded_config           =  YAML.load_file(config_file)
      @config_file            =  { 'name' => config_file,
        'modified_at' => File.mtime(config_file) }

      # Seperate config hashes into easier to use parts
      @user                    =  loaded_config['user']
      @bot                     =  loaded_config['bot']

      # Extract this to YAML defaults file
      config_defaults          = { 'own_tweets' => false,
                                   'keep_alive' => true,
                                     'per_hour' => 30,
                                        'debug' => false,
                                 'dont_refresh' => false,
                                       'active' => true,
                                       'log_to' => 'file'}

      # Merge specified config onto defaults
      @config = config_defaults.merge(loaded_config['config'])

      set_wait

      # Manually set "last_check" so update actually pulls prior tweets
      @last_check = Time.now - @config['wait']
      putd "Loaded config file"
    end

    # @config['wait'] is the number of seconds to wait
    def set_wait
      @config['wait'] = SEC_PER_HOUR / @config['per_hour']
    end

    def load_opts(args)
      options = OptionParser.new do |opts|
        opts.banner = "Twitter-sms bot help menu:\n"
        opts.banner += "==========================\n"
        opts.banner += "Usage #$0 [options]"

        # The problem with this is if the asked for config file doesn't exist
        opts.on('-c', '--config-file [FILE]',
                'Location of the config file to be loaded') do |filename|
          load_config(filename)
        end

        opts.on('-t', '--times-per-hour [TIMES]',
                'Indicate the amount of times per hour to check (> 0)') do |times|
          times = 1 if times <= 0
          @config['per_hour'] = times
        end

        opts.on('-o', '--own-tweets',
                "Makes your own tweets send in addition to followed account\'s tweets") do
          @config['own_tweets'] = true
        end

        opts.on('-s', '--single-check',
                'Forces the program to only check once, instead of continually') do
          @config['keep_alive'] = false
        end

        opts.on_tail('-h', '--help', 'display this help and exit') do
          puts opts
          exit
        end
      end

      options.parse!(args)
    end

    # Config is stale if a newer version exists in the filesystem than last checked
    def config_stale?
      return File.mtime(@config_file['name']) > @config_file['modified_at']
    end

    # Produce the content of the SMTP message to be sent
    def content(tweet)
      "From: #{@bot['email']}\n"+
        "To: #{@user['phone']}\n"+
        #On date line 2 '\n's are required for proper message
        "Date: #{Time.parse(tweet.created_at).rfc2822}\n\n"+
        "#{tweet.user.screen_name}: #{CGI.escapeHTML(tweet.text)}"
    end

    def self.filename_to_ary(path)
      path.split('/')[-1]
    end

  end
end

