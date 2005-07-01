require 'action_mailer/adv_attr_accessor'
require 'action_mailer/part'
require 'action_mailer/part_container'
require 'tmail/net'

module ActionMailer #:nodoc:
  # Usage:
  #
  #   class ApplicationMailer < ActionMailer::Base
  #     # Set up properties
  #     # (Properties can also be specified via accessor methods
  #     # i.e. self.subject = "foo") and instance variables (@subject = "foo").
  #     def signup_notification(recipient)
  #       recipients recipient.email_address_with_name
  #       subject    "New account information"
  #       body       Hash.new("account" => recipient)
  #       from       "system@example.com"
  #     end
  #
  #     # explicitly specify multipart messages
  #     def signup_notification(recipient)
  #       recipients      recipient.email_address_with_name
  #       subject         "New account information"
  #       from            "system@example.com"
  #
  #       part :content_type => "text/html",
  #         :body => render_message("signup-as-html", :account => recipient)
  #
  #       part "text/plain" do |p|
  #         p.body = render_message("signup-as-plain", :account => recipient)
  #         p.transfer_encoding = "base64"
  #       end
  #     end
  #
  #     # attachments
  #     def signup_notification(recipient)
  #       recipients      recipient.email_address_with_name
  #       subject         "New account information"
  #       from            "system@example.com"
  #
  #       attachment :content_type => "image/jpeg",
  #         :body => File.read("an-image.jpg")
  #
  #       attachment "application/pdf" do |a|
  #         a.body = generate_your_pdf_here()
  #       end
  #     end
  #
  #     # implicitly multipart messages
  #     def signup_notification(recipient)
  #       recipients      recipient.email_address_with_name
  #       subject         "New account information"
  #       from            "system@example.com"
  #       body(:account => "recipient")
  #
  #       # ActionMailer will automatically detect and use multipart templates,
  #       # where each template is named after the name of the action, followed
  #       # by the content type. Each such detected template will be added as
  #       # a separate part to the message.
  #       #
  #       # for example, if the following templates existed:
  #       #   * signup_notification.text.plain.rhtml
  #       #   * signup_notification.text.html.rhtml
  #       #   * signup_notification.text.xml.rxml
  #       #   * signup_notification.text.x-yaml.rhtml
  #       #
  #       # Each would be rendered and added as a separate part to the message,
  #       # with the corresponding content type. The same body hash is passed to
  #       # each template.
  #     end
  #   end
  #
  #   # After this post_notification will look for "templates/application_mailer/post_notification.rhtml"
  #   ApplicationMailer.template_root = "templates"
  #  
  #   ApplicationMailer.create_comment_notification(david, hello_world)  # => a tmail object
  #   ApplicationMailer.deliver_comment_notification(david, hello_world) # sends the email
  #
  # = Configuration options
  #
  # These options are specified on the class level, like <tt>ActionMailer::Base.template_root = "/my/templates"</tt>
  #
  # * <tt>template_root</tt> - template root determines the base from which template references will be made.
  #
  # * <tt>logger</tt> - the logger is used for generating information on the mailing run if available.
  #   Can be set to nil for no logging. Compatible with both Ruby's own Logger and Log4r loggers.
  #
  # * <tt>server_settings</tt> -  Allows detailed configuration of the server:
  #   * <tt>:address</tt> Allows you to use a remote mail server. Just change it away from it's default "localhost" setting.
  #   * <tt>:port</tt> On the off change that your mail server doesn't run on port 25, you can change it.
  #   * <tt>:domain</tt> If you need to specify a HELO domain, you can do it here.
  #   * <tt>:user_name</tt> If your mail server requires authentication, set the username and password in these two settings.
  #   * <tt>:password</tt> If your mail server requires authentication, set the username and password in these two settings.
  #   * <tt>:authentication</tt> If your mail server requires authentication, you need to specify the authentication type here. 
  #     This is a symbol and one of :plain, :login, :cram_md5
  #
  # * <tt>raise_delivery_errors</tt> - whether or not errors should be raised if the email fails to be delivered.
  #
  # * <tt>delivery_method</tt> - Defines a delivery method. Possible values are :smtp (default), :sendmail, and :test.
  #   Sendmail is assumed to be present at "/usr/sbin/sendmail".
  #
  # * <tt>perform_deliveries</tt> - Determines whether deliver_* methods are actually carried out. By default they are,
  #   but this can be turned off to help functional testing.
  #
  # * <tt>deliveries</tt> - Keeps an array of all the emails sent out through the Action Mailer with delivery_method :test. Most useful
  #   for unit and functional testing.
  #
  # * <tt>default_charset</tt> - The default charset used for the body and to encode the subject. Defaults to UTF-8. You can also 
  #   pick a different charset from inside a method with <tt>@charset</tt>.
  # * <tt>default_content_type</tt> - The default content type used for main part of the message. Defaults to "text/plain". You
  #   can also pick a different content type from inside a method with <tt>@content_type</tt>. 
  # * <tt>default_implicit_parts_order</tt> - When a message is built implicitly (i.e. multiple parts are assemble from templates
  #   which specify the content type in their filenames) this variable controls how the parts are ordered. Defaults to
  #   ["text/html", "text/enriched", "text/plain"]. Items that appear first in the array have higher priority in the mail client
  #   and appear last in the mime encoded message. You can also pick a different order from inside a method with
  #   <tt>@implicit_parts_order</tt>.
  class Base
    include ActionMailer::AdvAttrAccessor
    include ActionMailer::PartContainer

    private_class_method :new #:nodoc:

    cattr_accessor :template_root
    cattr_accessor :logger

    @@server_settings = { 
      :address        => "localhost", 
      :port           => 25, 
      :domain         => 'localhost.localdomain', 
      :user_name      => nil, 
      :password       => nil, 
      :authentication => nil
    }
    cattr_accessor :server_settings

    @@raise_delivery_errors = true
    cattr_accessor :raise_delivery_errors

    @@delivery_method = :smtp
    cattr_accessor :delivery_method
    
    @@perform_deliveries = true
    cattr_accessor :perform_deliveries
    
    @@deliveries = []
    cattr_accessor :deliveries

    @@default_charset = "utf-8"
    cattr_accessor :default_charset

    @@default_content_type = "text/plain"
    cattr_accessor :default_content_type

    @@default_implicit_parts_order = [ "text/html", "text/enriched", "text/plain" ]
    cattr_accessor :default_implicit_parts_order

    adv_attr_accessor :recipients, :subject, :body, :from, :sent_on, :headers,
                      :bcc, :cc, :charset, :content_type, :implicit_parts_order,
                      :template

    attr_reader       :mail

    # Instantiate a new mailer object. If +method_name+ is not +nil+, the mailer
    # will be initialized according to the named method. If not, the mailer will
    # remain uninitialized (useful when you only need to invoke the "receive"
    # method, for instance).
    def initialize(method_name=nil, *parameters)
      create!(method_name, *parameters) if method_name 
    end

    # Initialize the mailer via the given +method_name+. The body will be
    # rendered and a new TMail::Mail object created.
    def create!(method_name, *parameters)
      @bcc = @cc = @from = @recipients = @sent_on = @subject = nil
      @charset = @@default_charset.dup
      @content_type = @@default_content_type.dup
      @implicit_parts_order = @@default_implicit_parts_order.dup
      @template = method_name
      @parts = []
      @headers = {}
      @body = {}

      send(method_name, *parameters)

      # If an explicit, textual body has not been set, we check assumptions.
      unless String === @body
        # First, we look to see if there are any likely templates that match,
        # which include the content-type in their file name (i.e.,
        # "the_template_file.text.html.rhtml", etc.).
        if @parts.empty?
          templates = Dir.glob("#{template_path}/#{@template}.*")
          templates.each do |path|
            type = (File.basename(path).split(".")[1..-2] || []).join("/")
            next if type.empty?
            @parts << Part.new(:content_type => type,
              :disposition => "inline", :charset => charset,
              :body => render_message(File.basename(path).split(".")[0..-2].join('.'), @body))
          end
          unless @parts.empty?
            @content_type = "multipart/alternative"
            @parts = sort_parts(@parts, @implicit_parts_order)
          end
        end

        # Then, if there were such templates, we check to see if we ought to
        # also render a "normal" template (without the content type). If a
        # normal template exists (or if there were no implicit parts) we render
        # it.
        template_exists = @parts.empty?
        template_exists ||= Dir.glob("#{template_path}/#{@template}.*").any? { |i| i.split(".").length == 2 }
        @body = render_message(@template, @body) if template_exists

        # Finally, if there are other message parts and a textual body exists,
        # we shift it onto the front of the parts and set the body to nil (so
        # that create_mail doesn't try to render it in addition to the parts).
        if !@parts.empty? && String === @body
          @parts.unshift Part.new(:charset => charset, :body => @body)
          @body = nil
        end
      end

      # build the mail object itself
      @mail = create_mail
    end

    # Delivers the cached TMail::Mail object. If no TMail::Mail object has been
    # created (via the #create! method, for instance) this will fail.
    def deliver!
      raise "no mail object available for delivery!" unless @mail
      logger.info "Sent mail:\n #{mail.encoded}" unless logger.nil?

      begin
        send("perform_delivery_#{delivery_method}", @mail) if perform_deliveries
      rescue Object => e
        raise e if raise_delivery_errors
      end

      return @mail
    end

    private
      def render_message(method_name, body)
        initialize_template_class(body).render_file(method_name)
      end
        
      def template_path
        template_root + "/" + Inflector.underscore(self.class.name)
      end

      def initialize_template_class(assigns)
        ActionView::Base.new(template_path, assigns, self)
      end

      def sort_parts(parts, order = [])
        order = order.collect { |s| s.downcase }

        parts = parts.sort do |a, b|
          a_ct = a.content_type.downcase
          b_ct = b.content_type.downcase

          a_in = order.include? a_ct
          b_in = order.include? b_ct

          s = case
          when a_in && b_in
            order.index(a_ct) <=> order.index(b_ct)
          when a_in
            -1
          when b_in
            1
          else
            a_ct <=> b_ct
          end

          # reverse the ordering because parts that come last are displayed
          # first in mail clients
          (s * -1)
        end

        parts
      end

      def create_mail
        m = TMail::Mail.new

        m.subject, = quote_any_if_necessary(charset, subject)
        m.to, m.from = quote_any_address_if_necessary(charset, recipients, from)
        m.bcc = quote_address_if_necessary(bcc, charset) unless bcc.nil?
        m.cc  = quote_address_if_necessary(cc, charset) unless cc.nil?

        m.date = sent_on.to_time rescue sent_on if sent_on
        headers.each { |k, v| m[k] = v }

        if @parts.empty?
          m.set_content_type content_type, nil, { "charset" => charset }
          m.body = body
        else
          if String === body
            part = TMail::Mail.new
            part.body = body
            part.set_content_type content_type, nil, { "charset" => charset }
            part.set_content_disposition "inline"
            m.parts << part
          end

          @parts.each do |p|
            part = (TMail::Mail === p ? p : p.to_mail(self))
            m.parts << part
          end
          
          m.set_content_type(content_type, nil, { "charset" => charset }) if content_type =~ /multipart/
        end

        @mail = m
      end

      def perform_delivery_smtp(mail)
        destinations = mail.destinations
        mail.ready_to_send

        Net::SMTP.start(server_settings[:address], server_settings[:port], server_settings[:domain], 
            server_settings[:user_name], server_settings[:password], server_settings[:authentication]) do |smtp|
          smtp.sendmail(mail.encoded, mail.from, destinations)
        end
      end

      def perform_delivery_sendmail(mail)
        IO.popen("/usr/sbin/sendmail -i -t","w+") do |sm|
          sm.print(mail.encoded)
          sm.flush
        end
      end

      def perform_delivery_test(mail)
        deliveries << mail
      end

    class << self
      def method_missing(method_symbol, *parameters)#:nodoc:
        case method_symbol.id2name
          when /^create_([_a-z]\w*)/  then new($1, *parameters).mail
          when /^deliver_([_a-z]\w*)/ then new($1, *parameters).deliver!
          when "new" then nil
          else super
        end
      end

      def receive(raw_email)
        logger.info "Received mail:\n #{raw_email}" unless logger.nil?
        mail = TMail::Mail.parse(raw_email)
        mail.base64_decode
        new.receive(mail)
      end

    end
  end
end
