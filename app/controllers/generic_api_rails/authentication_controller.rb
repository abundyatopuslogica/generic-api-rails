require 'open-uri'

class GenericApiRails::AuthenticationController < GenericApiRails::BaseController
  skip_before_filter :api_setup

  def done
    render_error ApiError::INVALID_USERNAME_OR_PASSWORD and return false unless @credential
    
    @api_token = ApiToken.find_or_create_by(credential_id: @credential.id) if @credential
    
    if @credential and @api_token
      res = @credential.as_json(:only => [:id,:email])
      res = res.merge(@api_token.as_json(:only => [:token]))
    else
      raise "failed to create api token? should be impossible..."
    end
    
    render_result(res)
  end

  def facebook
    # By default, client-side authentication gives you a short-lived
    # token:
    short_lived_token = params[:access_token]

    fb_hash = GenericApiRails.config.facebook_hash

    app_id = fb_hash[:app_id]
    app_secret = fb_hash[:app_secret]

    # to upgrade it, hit this URI, and use the token it hands back:
    token_upgrade_uri = "https://graph.facebook.com/oauth/access_token?client_id=#{app_id}&client_secret=#{app_secret}&grant_type=fb_exchange_token&fb_exchange_token=#{short_lived_token}"

    begin
      res = URI.parse(token_upgrade_uri).read

      res_hash = Rack::Utils.parse_query res
    
      long_lived_token = res_hash['access_token']
    rescue Exception => x
      render :json => { :error => x }
      return
    end

    # at this point, we have verified that the credential is authorized by
    # Facebook- facebook has even given us a long-lived token to
    # manipulate this credential via FB.  Now, all we need is some details
    # about our credential, namely the credential ID, and email.  We use Koala
    # here because it is a more flexible endpoint for Facebook, and we
    # don't want to be using OAuth here - we already have the token we
    # need.

    @graph = Koala::Facebook::API.new(long_lived_token, APP_SECRET)
    fb_user = @graph.get_object('me')

    uid = fb_user['id']
    
    # create a hash that matches what oauth spits out, but we've done
    # it with Koala:
    
    @provider = 'facebook'
    @uid = uid
    @email = fb_user[:email]

    @credential = GenericApiRails.config.oauth_with.call(provider: 'facebook', uid: uid, email: fb_user[:email])

    done
  end

  def login
    username = params[:username] || params[:email] || params[:login]
    incoming_api_token = params[:api_token] || request.headers['api-token']

    password = params[:password]
    credential = nil

    api_token = nil

    logger.info "INCOMING API TOKEN '#{incoming_api_token.presence}'"

    if incoming_api_token.presence and not username and not password
      api_token = ApiToken.find_by_token(incoming_api_token) rescue nil
      credential = api_token.credential if api_token
      (api_token.destroy and api_token = nil) if not credential
    end

    if not api_token
      if username.blank? or password.blank?
        render_error ApiError::INVALID_USERNAME_OR_PASSWORD and return
      else
        @credential = GenericApiRails.config.login_with.call(username,password)
      end
    end

    logger.info "Credentials #{ credential }"
    done
  end

  def signup
    username = params[:username] || params[:login] || params[:email]
    password = params[:password]

    @credential = GenericApiRails.config.signup_with.call(username,password)
    
    done
  end
end
